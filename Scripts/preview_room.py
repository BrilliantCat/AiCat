"""Render the app's bundled living-room geometry and kitten from the portrait game camera."""
import json
import numpy as np
from PIL import Image
from scipy.spatial.transform import Rotation
from preview_kitten import ROOT, ctx, gl, program, vbuf, vao, fur, pose, sample, unit

folder=ROOT/"Assets/LivingRoom"
# Match CatRoomScenery.kittenScale (the ball and the rig share the same parent).
KITTEN_SCALE = 0.5625
layout=json.loads((folder/"SittingRoom.json").read_text())
data=(folder/"SittingRoom.mesh").read_bytes()
end=layout["vertices"]*48
scene=ctx.program(vertex_shader="""#version 330
uniform mat4 camera;
in vec3 p, n, col;in vec2 uv;
out vec3 normal, world, color;out vec2 coords;
void main(){gl_Position=camera*vec4(p,1);normal=n;color=col;world=p;coords=uv;}
""",fragment_shader="""#version 330
uniform sampler2D diffuse;
uniform int kind;
uniform float night;
uniform bool shadow;
in vec3 normal,world,color;in vec2 coords;out vec4 frag;
void main(){
if(shadow){
    vec2 q=(coords-.5)*2.;
    frag=vec4(.13,.10,.09,.32*exp(-3.8*dot(q,q))*(1.-smoothstep(.80,1.,max(abs(q.x),abs(q.y)))));
    return;
}
vec3 albedo=texture(diffuse,coords).rgb*color;
vec3 n=normalize(normal);
float sun=max(0.,dot(n,normalize(vec3(-.55,1.,.65))));
float key=mix(.79,.62,night)+mix(.24,.12,night)*sun;
vec3 d=vec3(1.77,1.65,-2.18)-world;
vec3 light=key*vec3(1.,.985,.97)+vec3(.24,.16,.07)*max(0.,dot(n,normalize(d)))/(1.+dot(d,d));
if(kind==1)light=vec3(1);
if(kind==2)light+=vec3(.19,.13,.055);
frag=vec4(albedo*light,1.);
}""")
gpu_v=ctx.buffer(data[:end]);gpu_i=ctx.buffer(data[end:])
room=ctx.vertex_array(scene,[(gpu_v,"3f 3f 2f 3f 4x","p","n","uv","col")],gpu_i,index_element_size=4)
textures={}
def texture(key):
    if key not in textures:
        im=Image.open(folder/key).convert("RGB") if key else Image.new("RGB",(1,1),"white")
        tex=ctx.texture(im.size,3,im.transpose(Image.Transpose.FLIP_TOP_BOTTOM).tobytes())
        tex.repeat_x=False;tex.repeat_y=False
        tex.build_mipmaps();textures[key]=tex
    return textures[key]


def render_room(night, size=(410,520), cat=(0,0), heading=-.54, clip="idle", t=.08, ball=None,
                frame=None, ball_rotation=None):
    w,h=size
    cat=np.array(cat)*KITTEN_SCALE
    if ball is not None: ball=np.array(ball)*KITTEN_SCALE
    focus=cat[0]*.4 if ball is None else cat[0]*.38+ball[0]*.15
    half=max(1.60 if ball is None else 2.10,abs(cat[0]-focus)+1.47*KITTEN_SCALE)
    if ball is not None: half=max(half,abs(ball[0]-focus)+.22)
    slope=max(1.48,half*h/w)/5.5
    eye=np.array([focus,2.20,6.30])
    back=unit(eye-[focus,1.02,0])
    right=unit(np.cross([0,1,0],back));up=np.cross(back,right)
    view=np.eye(4);view[:3,:3]=np.stack([right,up,back]);view[:3,3]=-view[:3,:3]@eye
    projection=np.array([[h/w/slope,0,0,0],[0,1/slope,0,0],[0,0,-100.1/99.9,-20/99.9],[0,0,-1,0]])
    camera=(projection@view).T.astype("f").tobytes()
    buf=ctx.simple_framebuffer((w*2,h*2),components=4)
    buf.use();ctx.clear(.43,.39,.34,1,depth=1)
    scene["camera"].write(camera);scene["night"].value=float(night);scene["shadow"].value=False
    files={"rug":"Kilim.jpg","linen":"Linen.jpg","oak":"Oak.jpg","window":"StreetNight.jpg" if night else "StreetDay.jpg"}
    for part in layout["parts"]:
        key=part["material"]
        texture(files.get(key)).use()
        scene["kind"].value={"window":1,"shade":2}.get(key,0)
        room.render(first=part["first"],vertices=part["count"])
    # The kitten pose, coat UVs and skin weights come directly from the packaged model.
    mesh=pose(sample(clip,t) if frame is None else frame)
    rotation=Rotation.from_euler("y",heading).as_matrix()
    mesh[:,:3]=KITTEN_SCALE*(mesh[:,:3]@rotation.T)+[cat[0],0,cat[1]]
    mesh[:,3:6]=mesh[:,3:6]@rotation.T
    program["camera"].write(camera)
    # Soft contact beneath the body. SceneKit uses its own directional shadow map on iOS.
    corners=KITTEN_SCALE*np.array([[-.60,0,-1.33],[.60,0,-1.33],[-.60,0,1.33],[.60,0,1.33]])@rotation.T+[cat[0],.001,cat[1]]
    quad=np.c_[corners,np.tile([0,1,0],(4,1)),[[0,0],[1,0],[0,1],[1,1]],np.ones((4,3))].astype("f")
    vb=ctx.buffer(quad.tobytes())
    shade=ctx.vertex_array(scene,[(vb,"3f 3f 2f 3f","p","n","uv","col")])
    scene["shadow"].value=True;ctx.enable(gl.BLEND);ctx.blend_func=gl.SRC_ALPHA,gl.ONE_MINUS_SRC_ALPHA
    shade.render(mode=gl.TRIANGLE_STRIP);ctx.disable(gl.BLEND)
    shade.release();vb.release();scene["shadow"].value=False
    fur.use();program["shadow"].value=False
    vbuf.write(mesh.tobytes());vao.render()
    if ball is not None:
        a,b=np.meshgrid(np.linspace(0,2*np.pi,37),np.linspace(0,np.pi,21))
        n=np.stack([np.cos(a)*np.sin(b),np.cos(b),np.sin(a)*np.sin(b)],2)
        rgb=np.broadcast_to([.82,.41,.22],n.shape).copy()
        for angle in [.23,.36,1.82]:
            band=np.abs(-np.sin(angle)*n[:,:,0]+np.cos(angle)*n[:,:,1])<.055
            rgb[band]=[.96,.76,.46]
        if ball_rotation is not None:
            n=n@ball_rotation.T
        radius=.095*KITTEN_SCALE
        vertices=np.concatenate([n*radius+[ball[0],radius,ball[1]],n,np.zeros((*a.shape,2)),rgb],2).astype("f")
        i=(np.arange(20)[:,None]*37+np.arange(36)).ravel()
        tri=np.stack([i,i+37,i+1,i+1,i+37,i+38],1).astype("u4")
        vb=ctx.buffer(vertices.tobytes());ib=ctx.buffer(tri.tobytes())
        sphere=ctx.vertex_array(scene,[(vb,"3f 3f 2f 3f","p","n","uv","col")],ib,index_element_size=4)
        texture(None).use();scene["kind"].value=0;sphere.render()
        sphere.release();ib.release();vb.release()
    image=Image.frombytes("RGB",buf.size,buf.read(components=3,alignment=1)).transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    buf.release()
    return image.resize(size,Image.Resampling.LANCZOS)

if __name__=="__main__":
    out=Image.new("RGB",(820,520))
    out.paste(render_room(False),(0,0))
    out.paste(render_room(True,cat=(-.70,.09),heading=1.30,clip="trot",t=.13,ball=(1.78,.53)),(410,0))
    out.save(ROOT/"Previews/SittingRoom.jpg",quality=94)
