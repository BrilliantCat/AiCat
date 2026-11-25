"""Render the shipped skin and its clips for visual review (moderngl, NumPy, SciPy, Pillow)."""
import json
from pathlib import Path

import moderngl as gl
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from scipy.spatial.transform import Rotation

ROOT=Path(__file__).resolve().parents[1]
asset=ROOT/"Assets/CatModel/BritishKitten"
model=json.loads(asset.with_suffix(".json").read_text())
raw=asset.with_suffix(".mesh").read_bytes()
dtype=np.dtype([("p","<f4",3),("n","<f4",3),("c","u1",4),("j","u1",4),("w","<f4",4),("uv","<f4",2)])
v=np.frombuffer(raw,dtype,model["vertices"])
f=np.frombuffer(raw,"<u4",offset=len(v)*dtype.itemsize)
assert len(f)==model["triangles"]*3
origins=np.array(model["origins"])
parents=model["parents"]
ctx=gl.create_standalone_context()
ctx.enable(gl.DEPTH_TEST)
program=ctx.program(vertex_shader="""#version 330
uniform mat4 camera;
uniform bool shadow;
in vec3 pos, normal, coat;
in vec2 furUV;out vec2 uv;
out vec3 n, c;
void main(){vec3 vertex=shadow ? vec3(pos.x+.35*pos.y,0,pos.z-.24*pos.y) : pos;gl_Position=camera*vec4(vertex,1); n=normal;c=coat;uv=furUV;}
""", fragment_shader="""#version 330
in vec3 n,c;in vec2 uv;uniform sampler2D fur;
out vec4 color;
void main(){
vec3 norm=normalize(n);
float soft=max(0.,dot(norm,normalize(vec3(-.65,.84,.96))));
float bounce=max(0.,dot(norm,normalize(vec3(.45,.4,-.83))));
vec3 light=vec3(.59,.60,.62)+soft*vec3(.46,.44,.40)+bounce*vec3(.12,.115,.105);
float fiber=uv.x < -9. ? 1. : texture(fur,uv).r; color=vec4(c*light*fiber,1.);
}""")
texture=Image.open(asset.with_name("SilverCoat.png")).convert("RGB")
fur=ctx.texture(texture.size,3,texture.transpose(Image.Transpose.FLIP_TOP_BOTTOM).tobytes())
fur.build_mipmaps();fur.use()
uv=np.full((len(v),2),-10,dtype="f")
uv[:model["coatVertices"]]=v["uv"][:model["coatVertices"]]
uvbuf=ctx.buffer(uv.tobytes())
vbuf=ctx.buffer(reserve=len(v)*36)
vao=ctx.vertex_array(program,[(vbuf,"3f 3f 3f","pos","normal","coat"),(uvbuf,"2f","furUV")],ctx.buffer(f.tobytes()))
def unit(a):return a/np.linalg.norm(a)


def pose(frame):
    quats=np.array(frame[4:]).reshape(-1,4)
    M=Rotation.from_quat(quats).as_matrix()
    pos=origins.copy();pos[0]+=frame[:3]
    for i,parent in enumerate(parents):
        if model["bones"][i].startswith("eye"):
            M[i,:,1]*=frame[3]
        if parent>=0:
            rest=origins[i]-origins[parent]
            if model["bones"][i].startswith("eye"):
                rest[2]-=(1-frame[3])*.046
            pos[i]=pos[parent]+M[parent]@rest
            M[i]=M[parent]@M[i]
    xyz=np.zeros((len(v),3))
    n=np.zeros_like(xyz)
    normals=np.linalg.inv(M).transpose(0,2,1)
    for k in range(4):
        idx=v["j"][:,k]; wt=v["w"][:,k,None]
        xyz+=wt*(np.einsum("nij,nj->ni",M[idx],v["p"]-origins[idx])+pos[idx])
        n+=wt*np.einsum("nij,nj->ni",normals[idx],v["n"])
    return np.c_[xyz,n,v["c"][:,:3]/255].astype("f")


def mix(a,b,t):
    a,b=np.array(a),np.array(b)
    q,r=a[4:].reshape(-1,4),b[4:].reshape(-1,4)
    dot=(q*r).sum(1)
    r=r*np.where(dot<0,-1,1)[:,None]
    theta=np.arccos(np.clip(abs(dot),0,1))
    sine=np.sin(theta)
    sinc=lambda v:np.sin(v*theta)/np.maximum(sine,1e-12)
    qq=sinc(1-t)[:,None]*q+sinc(t)[:,None]*r
    qq[theta<.001]=q[theta<.001]*(1-t)+r[theta<.001]*t
    return np.r_[a[:4]*(1-t)+b[:4]*t,qq.flatten()]


def sample(clip,t):
    c=model["clips"][clip]
    entry=c.get("entry")
    if entry and t<entry["seconds"]:
        frames=entry["frames"]
        at=t/entry["seconds"]*(len(frames)-1)
    else:
        frames=c["frames"]
        if entry: t-=entry["seconds"]
        at=(t/c["seconds"]%1)*len(frames)
    i=int(at)%len(frames)
    return mix(frames[i],frames[(i+1)%len(frames)],at%1)


def render(frame,azimuth,size=(440,360),span=2.08,offset=0,transparent=False,target=(0,.74,-.15)):
    W,H=size
    buf=ctx.simple_framebuffer((W*2,H*2),components=4)
    buf.use();ctx.clear(0,0,0,0,depth=1)
    a=np.radians(azimuth);e=.12
    front=unit(np.array([np.sin(a),e,np.cos(a)]))
    right=unit(np.cross([0,1,0],front));up=np.cross(front,right)
    target=np.asarray(target)
    basis=np.stack([right/(span*.5*W/H),up/(span*.5),-front/4])
    mat=np.eye(4);mat[:3,:3]=basis;mat[:3,3]=-basis@target
    mat[0,3]+=offset
    program["camera"].write(mat.T.astype("f").tobytes())
    mesh=pose(frame);vbuf.write(mesh.tobytes())
    if not transparent:
        program["shadow"].value=True;vao.render()
        shade=Image.frombytes("RGBA",buf.size,buf.read(components=4,alignment=1)).getchannel("A").transpose(Image.Transpose.FLIP_TOP_BOTTOM)
        ctx.clear(0,0,0,0,depth=1)
    program["shadow"].value=False;vao.render()
    image=Image.frombytes("RGBA",buf.size,buf.read(components=4,alignment=1)).transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    buf.release()
    if not transparent:
        base=Image.new("RGBA",image.size,(49,57,60,255))
        base.paste((27,33,35,255),(0,0,*image.size),shade.filter(ImageFilter.GaussianBlur(6)).point(lambda a:a*.69))
        base.alpha_composite(image);image=base.convert("RGB")
    return image.resize(size,Image.Resampling.LANCZOS)


def widget_art():
    folder=ROOT/"AiCat-Visuals"/"kitten"
    folder.mkdir(exist_ok=True)
    poses={"idle":("idle",2.4,49),"purr":("purr",1.1,30),"play":("trot",.09,68),
           "sleep":("sleep",3.0,42),"eat":("eat",.65,62),"computer":("computer",.24,47),
           "groom":("groom",.33,-37)}
    for name,(clip,time,angle) in poses.items():
        picture=render(sample(clip,time),angle,(704,544),2.5,transparent=True)
        bounds=picture.getchannel("A").getbbox()
        assert bounds and bounds[0]>0 and bounds[2]<picture.width
        picture=picture.crop(bounds)
        picture.thumbnail((450,450),Image.Resampling.LANCZOS)
        picture.save(folder/(name+".png"),optimize=True)
    for name,clip,time in [("peek","idle",2),("think","think",.6),("sleep","sleep",3.0)]:
        frame=sample(clip,time)
        head=pose(frame)
        head_index=model["bones"].index("head")
        head_mask=(v["j"][:,3]==head_index)&(v["w"][:,3]>.9)
        center=(head[head_mask,:3].max(0)+head[head_mask,:3].min(0))/2
        # Portrait crop for the compact/minimal Island. The whole-body artwork is used when expanded.
        portrait=render(frame,24,(160,120),.72,target=center,transparent=True)
        portrait.save(folder/(name+"-leading.png"),optimize=True)


def main():
    out=ROOT/"Previews";out.mkdir(exist_ok=True)
    hero=Image.new("RGB",(1320,404),(49,57,60))
    draw=ImageDraw.Draw(hero)
    font=ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf",19) if Path("C:/Windows/Fonts/segoeui.ttf").exists() else ImageFont.load_default()
    idle=sample("idle",.08)
    for i,(az,name) in enumerate([(22,"Крупный план"),(89,"Профиль"),(43,"Три четверти")]):
        view=render(idle,az,span=.99,target=(0,1.07,.71)) if i==0 else render(idle,az)
        hero.paste(view,(440*i,0));draw.text((440*i+20,367),name,font=font,fill="#e6e0d8")
    hero.save(out/"BritishKitten.png")
    fps=18;frames=[]
    for i in range(109):
        t=i/fps
        if t<1.6: frame=sample("walk",t)
        else:
            u=np.clip((t-1.6)/.36,0,1)
            frame=mix(sample("walk",1.6),sample("sleep",t-1.6),u*u*(3-2*u))
        travel=min(t,1.6)*.58
        projected=travel*np.sin(np.radians(55))/(1.02*468/330)
        frames.append(render(frame,55,(468,330),2.04,.32-projected))
    frames[0].save(out/"BritishKitten-motion.gif",save_all=True,append_images=frames[1:],duration=round(1000/fps),loop=0,disposal=2)
    widget_art()

if __name__=="__main__":main()
