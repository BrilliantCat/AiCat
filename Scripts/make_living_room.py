"""Bake the sitting room for SceneKit. Coordinates are Y up with the rug surface at zero."""
from collections import defaultdict
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy.spatial.transform import Rotation

OUT = Path(__file__).resolve().parents[1] / "Assets/LivingRoom"
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(2311)


def write_fabric():
    """A flatwoven kilim. The border, field and yarn share one continuous surface."""
    w, h = 1024, 640
    y, x = np.indices((h,w))
    edge = np.minimum.reduce([x, w-1-x, y, h-1-y])
    field = np.full((h,w,3), [157,74,73], dtype=float)
    for width, color in [(58,[225,179,124]), (52,[53,87,96]), (37,[218,161,92]),
                         (29,[104,58,80]), (23,[222,173,128]), (15,[67,109,109]), (8,[196,129,105])]:
        field[edge < width] = color
    # Staggered, open lozenges leave the centre quiet enough for the kitten silhouette.
    for row in range(5):
        for col in range(7):
            dx = np.abs(x - (100+col*147+(row%2)*73))
            dy = np.abs(y - (104+row*111))
            d = dx/53 + dy/40
            jewel = ((51,101,110),(113,69,91),(202,131,75))[(row+col)%3]
            field[(d<.86)&(edge>62)] = jewel
            field[(np.abs(d-1)<.08)&(edge>62)] = [223,173,128]
            field[(np.abs(d-.53)<.055)&(edge>62)] = [224,157,102]
            field[(d<.15)&(edge>62)] = [235,193,146]
    weave = 2.4*np.sin(x*np.pi/2)+3*np.cos(y*np.pi/3)+rng.normal(0,2.8,(h,w))
    Image.fromarray(np.clip(field+weave[:,:,None],0,255).astype('uint8')).save(OUT/"Kilim.jpg",quality=89)
    y,x=np.indices((256,256))
    linen=237+5*np.cos(y*np.pi/2)+3*np.cos(x*np.pi/2)+rng.normal(0,4,(256,256))
    Image.fromarray(np.clip(linen,0,255).astype('uint8')).convert("RGB").save(OUT/"Linen.jpg",quality=82)
    y,x=np.indices((256,768))
    grain=np.sin(y*.62+.9*np.sin(x*.022)+.007*x)+.55*np.sin(y*1.32+.8*np.cos(x*.018))
    wood=np.array([165,117,82])+grain[:,:,None]*np.array([9,8,6])+rng.normal(0,2,(256,768,1))
    Image.fromarray(np.clip(wood,0,255).astype('uint8')).save(OUT/"Oak.jpg",quality=87)


def street(night):
    """Small painted view through the sash window, with distinct daylight and lamplight."""
    r=np.random.default_rng(160)
    w,h=640,400
    high,low=([45,55,94],[169,121,137]) if night else ([134,189,207],[246,199,163])
    sky=np.linspace(high,low,h)[:,None,:].repeat(w,axis=1)
    image=Image.fromarray(sky.astype('uint8')); draw=ImageDraw.Draw(image)
    for x,y in [(37,78),(176,127),(324,68),(552,111)]:
        draw.polygon([(x,y),(x+28,y-4),(x+42,y-11),(x+67,y-10),(x+74,y-4),(x+102,y)],
                     fill=('#656487' if night else '#e8d9c9'))
    draw.ellipse((425,48,461,84),fill=('#eadfbd' if night else '#fff0cb'))
    for layer in [0,1]:
        x=-50
        while x<w:
            width=int(r.integers(55,119))
            top=int(r.integers(189,242))+46*layer
            tone=int(r.integers(-8,9))
            paint=([187,157,138],[182,161,148],[170,166,148],[187,145,129])
            tint=np.array(([70,76,97] if layer==0 else [55,64,75]) if night else paint[int(r.integers(4))])+tone
            wall=tuple(tint.tolist())
            roof=tuple((tint-19).tolist())
            draw.rectangle((x,top,x+width,h),fill=wall)
            draw.polygon([(x-5,top),(x+11,top-18),(x+width-13,top-18),(x+width+4,top)],fill=roof)
            draw.rectangle((x+13,top-33,x+21,top-15),fill=roof)
            for xx in range(x+9,x+width-6,18):
                for yy in range(top+15,h,30):
                    lit=night and r.random()>.45
                    draw.rectangle((xx,yy,xx+7,yy+13),fill=('#e4bd86' if lit else roof))
            x+=width+3
    for x in [2,29,78,539,588,629]:
        y=int(r.integers(267,334))
        draw.line((x,h,x+5,y),fill='#66564e',width=5)
        palette=('#394957','#46535e','#525767') if night else ('#87947a','#b59c69','#b68269')
        for j in range(72):
            dx,dy=r.normal(0,[14,12]);size=r.uniform(3,10)
            draw.ellipse((x+dx-size,y+dy-size,x+dx+size,y+dy+size),fill=palette[int((dx-dy)>9) + int((dx-dy)>20)])
    image.save(OUT/("StreetNight.jpg" if night else "StreetDay.jpg"),quality=88)


vertices=[]
groups=defaultdict(list)


def add(pos, normals, uv, triangles, color, material, center, rot):
    start=sum(len(a) for a in vertices)
    matrix=Rotation.from_euler("xyz",rot).as_matrix()
    p=np.asarray(pos)@matrix.T+center
    n=np.asarray(normals)@matrix.T
    color=np.broadcast_to(np.array(color)/255.,p.shape)
    vertices.append(np.c_[p,n,uv,color,np.ones(len(p))].astype("<f4"))
    tri=np.array(triangles).reshape(-1,3)
    # Outward winding matters for both the window and the directional shadow map.
    cross=np.cross(p[tri[:,1]]-p[tri[:,0]],p[tri[:,2]]-p[tri[:,0]])
    flip=(cross*n[tri[:,0]]).sum(1)<0
    tri[flip]=tri[flip][:,::-1]
    groups[material].append((tri+start).astype("<u4"))


def grid_faces(rows,cols):
    a=(np.arange(rows-1)[:,None]*cols+np.arange(cols-1)).ravel()
    return np.vstack([np.stack([a,a+1,a+cols],1),np.stack([a+1,a+cols+1,a+cols],1)])


def box(center,size,color,bevel=.018,material="matte",rot=(0,0,0)):
    half=np.array(size)/2
    r=min(bevel,min(half)*.92)
    for axis in range(3):
        u,v=(axis+1)%3,(axis+2)%3
        if axis==1: u,v=0,2
        for sign in [-1,1]:
            def samples(d):
                if r<.001: return [-d,d]
                return [-d,-d+.35*r,-d+r,d-r,d-.35*r,d]
            a,b=np.meshgrid(samples(half[u]),samples(half[v]))
            p=np.empty((a.size,3));p[:,axis]=sign*half[axis];p[:,u]=a.ravel();p[:,v]=b.ravel()
            if r>=.001:
                base=np.clip(p,-half+r,half-r)
                n=p-base;n/=np.linalg.norm(n,axis=1)[:,None];p=base+r*n
            else:
                n=np.zeros_like(p);n[:,axis]=sign
            uv=p[:,[u,v]]/np.array(size)[[u,v]]+.5
            add(p,n,uv,grid_faces(*a.shape),color,material,center,rot)


def lathe(center,profile,color,segments=32,material="matte",scale=(1,1,1),rot=(0,0,0)):
    """Revolve a radius/height profile for pottery, lamps, table and leaves."""
    radius,y=np.asarray(profile).T
    a=np.linspace(0,2*np.pi,segments+1)
    cos,sin=np.cos(a),np.sin(a)
    p=np.stack([radius[:,None]*cos,np.broadcast_to(y[:,None],(len(y),len(a))),radius[:,None]*sin],2)
    dr,dy=np.gradient(radius),np.gradient(y)
    n=np.stack([dy[:,None]*cos,np.broadcast_to(-dr[:,None],p.shape[:2]),dy[:,None]*sin],2)/scale
    n/=np.maximum(np.linalg.norm(n,axis=2,keepdims=True),1e-8)
    uv=np.stack(np.meshgrid(a/(2*np.pi),np.linspace(0,1,len(y))),axis=-1)
    add((p*scale).reshape(-1,3),n.reshape(-1,3),uv.reshape(-1,2),grid_faces(*p.shape[:2]),color,material,center,rot)


def curtain(x,width,phase):
    col,row=np.meshgrid(np.linspace(0,1,65),np.linspace(0,1,9))
    ripple=col*8*np.pi+phase
    xp=x+(col-.5)*width*(1-.18*np.sin(row*np.pi))
    yp=1.04+1.98*row+.018*np.cos(ripple)*(1-row)**8
    zp=-2.76+.058*np.cos(ripple)+.028*(1-row)**2
    p=np.stack([xp,yp,zp],2)
    n=np.cross(np.gradient(p,axis=1),np.gradient(p,axis=0));n/=np.linalg.norm(n,axis=2,keepdims=True)
    add(p.reshape(-1,3),n.reshape(-1,3),np.stack([col,row],2).reshape(-1,2),
        grid_faces(*col.shape),[223,164,144],"linen",(0,0,0),(0,0,0))


white=(255,255,255); walnut=(91,58,51); plaster=(232,199,166); teal=(59,112,122)
box((0,2,-3.16),(14,8,.15),plaster)
box((0,.52,-3.073),(14,1.04,.07),(99,139,137))
for x in np.arange(-6.6,7,.56):
    box((x,.51,-3.026),(.032,.91,.032),(117,155,148),.004)
box((0,.09,-3.025),(14,.18,.11),(89,117,112))
box((0,1.05,-3.02),(14,.056,.12),(146,164,146))
for i in range(19):
    z=-3.05+i*.48
    for j in range(5):
        tint=round(rng.uniform(.84,1)*255)
        box((-6+j*3+(i%2)*1.5,-.088,z),(2.995,.10,.475),(tint,)*3,.004,"oak")
box((0,-.021,.05),(5.1,.040,3.05),white,.012,"rug")

# Window, linen curtains, and an aged oak sill.
furnishings_start=len(vertices)
box((-.56,2.02,-3.03),(2.68,1.75,.11),walnut)
box((-.56,2.02,-2.96),(2.54,1.61,.015),white,0,"window")
for x in [-1.05,-.05]:
    box((x,2.02,-2.93),(.039,1.61,.038),walnut)
box((-.56,2.01,-2.93),(2.54,.037,.038),walnut)
box((-.56,1.13,-2.92),(2.91,.095,.37),(230,214,190),.02,"oak")
box((-.56,3.04,-2.77),(3.24,.041,.044),walnut)
curtain(-1.87,.48,.5);curtain(.76,.43,.2)
for i,(height,tint) in enumerate([(.18,(146,95,78)),(.20,(114,132,121)),(.157,(205,181,137))]):
    box((-1.45+.065*i,1.177+height/2,-2.81),(.060,height,.12),tint,.005)

# Low upholstered sofa with back cushions and tapered wood feet.
for x in [-1.83,.24]:
    for z in [-2.66,-2.14]:
        lathe((x,0,z),[(.049,-.03),(.064,.18)],walnut,12)
box((-.80,.245,-2.41),(2.48,.24,.89),teal,.10,"linen")
box((-.80,.61,-2.80),(2.48,.65,.23),teal,.105,"linen",(-.07,0,0))
for x in [-1.37,-.24]:
    box((x,.435,-2.36),(1.09,.18,.70),(77,135,142),.085,"linen")
    box((x,.72,-2.68),(1.10,.45,.19),(81,137,143),.090,"linen",(-.12,0,0))
for x in [-2,.40]:
    box((x,.50,-2.40),(.19,.51,.92),teal,.092,"linen")
for x,color,zrot in [(-1.62,(197,99,84),-.19),(-1.22,(221,170,89),.16),(.08,(139,96,131),.21)]:
    box((x,.72,-2.45),(.37,.37,.16),color,.078,"linen",(-.22,0,zrot))

# A striped wool throw follows the back cushion, seat and front edge of the sofa.
path=np.array([[-2.78,.94],[-2.70,.968],[-2.60,.95],[-2.55,.87],[-2.50,.57],
               [-2.44,.555],[-2.17,.555],[-2.025,.546],[-1.982,.50],[-1.936,.39],[-1.934,.18]])
u,t=np.meshgrid(np.linspace(-.5,.5,25),np.linspace(0,len(path)-1,81))
z=np.interp(t,np.arange(len(path)),path[:,0])
y=np.interp(t,np.arange(len(path)),path[:,1])
fold=.015*np.cos(u*8*np.pi+t*.24)
p=np.stack([-.67+.46*u+.05*np.sin(t*.4),y+fold,z+fold*.7],2)
n=np.cross(np.gradient(p,axis=0),np.gradient(p,axis=1))
n/=np.linalg.norm(n,axis=2,keepdims=True)
colors=np.empty_like(p)
colors[:]=[211,157,74]
colors[(t>8.55)&(t<8.84)]=[109,74,94]
colors[(t>9.1)&(t<9.37)]=[242,205,141]
add(p.reshape(-1,3),n.reshape(-1,3),np.stack([u+.5,t/10],2).reshape(-1,2),
    grid_faces(*t.shape),colors.reshape(-1,3),"linen",(0,0,0),(0,0,0))
for tip in p[-1,::2]:
    lathe(tip,[(.002,-.04),(.008,-.023),(.004,0)],(222,179,111),6)

# Warm reading corner and a ceramic planter. Keep furniture outside the chase area.
lathe((1.44,0,-2.35),[(.005,.005),(.24,.015),(.25,.042),(.19,.081),(.035,.09),(.026,1.48)],
      (146,111,72))
lathe((1.44,1.49,-2.35),[(.36,-.17),(.366,-.15),(.22,.23),(.213,.242)],
      (245,210,153),48,"shade")
lathe((.89,0,-2.15),[(.13,.015),(.16,.034),(.035,.08),(.034,.45),(.23,.47),(.235,.50),(.002,.51)],
      walnut,28)
lathe((.89,.51,-2.15),[(.078,0),(.092,.013),(.11,.142),(.113,.156),(.091,.158)],
      (181,117,90),24)
for i in range(11):
    a=i*2.4;h=.12+(i%4)*.035
    lathe((.89+.055*np.sin(a),.70+h*.18,-2.15+.055*np.cos(a)),
          [(.002,-h*.4),(.032,0),(.044,h*.4),(.002,h)],(100+i%3*9,128+i%4*7,94),8,
          scale=(1,1,.42),rot=(.53*np.cos(a),a,.50*np.sin(a)))

# A small framed botanical print, on the other side of the lamp.
box((1.64,2.09,-3.014),(.71,.87,.07),walnut)
box((1.64,2.09,-2.968),(.64,.80,.025),(236,225,198))
for i in range(6):
    y=1.88+i*.070
    box((1.64,y,-2.949),(.008,.08,.004),(128,119,86),0)
    s=(-1)**i
    lathe((1.64+s*.039,y+.018,-2.943),[(.002,-.061),(.026,-.010),(.021,.024),(.001,.061)],
          (125,140,111),12,scale=(1,1,.12),rot=(0,0,-s*.69))


for panel in vertices[furnishings_start:]:
    anchor=np.array([0,0,-2.75])
    panel[:,:3]=anchor+1.23*(panel[:,:3]-anchor)


if __name__=="__main__":
    write_fabric()
    street(False); street(True)
    data=np.concatenate(vertices)
    chunks=[]; index=[]; cursor=0
    for key, group in groups.items():
        faces=np.concatenate(group).reshape(-1)
        chunks.append(dict(material=key,first=cursor,count=len(faces)))
        index.append(faces);cursor+=len(faces)
    faces=np.concatenate(index).astype("<u4")
    assert np.isfinite(data).all() and faces.max()<len(data)
    (OUT/"SittingRoom.mesh").write_bytes(data.tobytes()+faces.tobytes())
    (OUT/"SittingRoom.json").write_text(json.dumps(dict(vertices=len(data),parts=chunks),separators=(",",":")),encoding="utf-8")
    print(f"Living room: {len(data)} vertices, {cursor//3} triangles, {len(chunks)} materials")
