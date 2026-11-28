"""Author the silver kitten's bind surface, skin weights, coat and face in metres (Y up, +Z nose).

Run with NumPy, SciPy, scikit-image and Pillow. The shipped app only reads the baked resources.
"""
import json
from pathlib import Path

import numpy as np
from skimage.measure import marching_cubes
from scipy.ndimage import gaussian_filter, map_coordinates
from PIL import Image

from kitten_motion import BONES, ORIGINS, PARENTS, TAIL, LEGS, make_clips

OUT = Path(__file__).resolve().parents[1] / "Assets/CatModel"
rng = np.random.default_rng(187)
STEP = .025
origin = np.array([-.58, -.08, -1.69])
axes = [np.arange(lo, hi, STEP, dtype=np.float32) for lo, hi in zip(origin, [.59, 1.69, 1.30])]
grid = np.stack(np.meshgrid(*axes, indexing="ij"), axis=-1)
fields, owners = [], []


def add(bone, distance):
    fields.append(distance.astype("f"))
    owners.append(BONES.index(bone))


def oval(bone, center, radii, pitch=0):
    x, y, z = (grid - center).T
    c, s = np.cos(pitch), np.sin(pitch)
    local = np.stack([x, c*y+s*z, -s*y+c*z], axis=0).T
    add(bone, (np.linalg.norm(local/radii, axis=-1)-1)*min(radii))


def tapered(bone, start, end, r0, r1):
    start, end = np.asarray(start), np.asarray(end)
    axis = end-start
    f = np.clip(np.sum((grid-start)*axis, axis=-1)/axis.dot(axis), 0, 1)
    add(bone, np.linalg.norm(grid-start-f[..., None]*axis, axis=-1) - (r0+(r1-r0)*f))


oval("pelvis", (0,.655,-.36), (.276,.309,.359))
oval("spine", (0,.685,-.035), (.272,.284,.442))
oval("chest", (0,.713,.31), (.272,.304,.341), .10)
oval("neck", (0,.903,.445), (.220,.293,.227), .40)
oval("head", (0,1.082,.646), (.357,.295,.277), .05)
oval("head", (0,.943,.831), (.171,.119,.162))
oval("head", (0,1.048,.884), (.067,.094,.086), .29)
for s, side in [(-1,"L"),(1,"R")]:
    oval("head", (s*.223,1.000,.740), (.151,.160,.160))
    oval("head", (s*.084,.982,.932), (.100,.074,.107))
    oval("head", (s*.135,1.174,.815), (.106,.043,.064), -.15)
    # Ears taper in both axes, lean outwards, with a rolled rim and a scooped front.
    x,y,z = np.moveaxis(grid,-1,0)
    t = np.clip((y-1.221)/.215,0,1)
    width = .120*np.sqrt(1-t)+.006
    depth = .077*np.sqrt(1-t)+.007
    cx, cz = s*(.199+.045*t), .591-.044*t
    radial = np.sqrt(((x-cx)/width)**2+((z-cz)/depth)**2)-1
    ear = np.maximum.reduce([radial*depth,1.215-y,y-1.436])
    scoop = (np.sqrt(((x-cx)/(.060*(1-t)+.009))**2+((z-cz-.068*(1-t)-.018)/(.042*(1-t)+.010))**2+((y-1.350)/.070)**2)-1)*.040
    add("ear"+side,np.maximum(ear,-scoop))

for i in range(len(TAIL)-1):
    tapered("tail"+str(i), TAIL[i], TAIL[i+1], .112-i*.008, .105-i*.009)

for label, points in LEGS.items():
    hind=label.startswith("hind")
    if hind:
        hip,knee=np.asarray(points[:2])
        oval(label+"0",hip*.61+knee*.39,(.157,.246,.176),-.30)
    for i,(a,b) in enumerate(zip(points,points[1:])):
        rad = [.138,.090,.050,.040] if hind else [.107,.079,.054,.047]
        tapered(label+str(i),a,b,rad[i],rad[i+1])
    x,y,z = points[-1]
    pad_radii=(.073,.052,.111) if hind else (.079,.058,.110)
    oval(label+"3",(x,.070,z+.038),pad_radii)
    for toe in [-1,0,1]:
        oval(label+"3",(x+toe*.042,.054,z+.103-.011*abs(toe)),(.034,.034,.045))

D = np.stack(fields,axis=-1)
del fields
nearest = D.min(axis=-1)
k = .022
sdf = nearest-k*np.log(np.exp((nearest[...,None]-D)/k).sum(axis=-1))
v, faces, normal, _ = marching_cubes(sdf, level=0, spacing=(STEP,)*3, allow_degenerate=False)
v += origin
# scikit-image normals point toward decreasing field. Flip to the air side.
normal *= -1
def unit(a):
    return a / np.maximum(1e-12,np.linalg.norm(a,axis=-1,keepdims=True))
area = np.cross(v[faces[:,1]]-v[faces[:,0]],v[faces[:,2]]-v[faces[:,0]])
if np.sum(area*normal[faces[:,0]])<0:
    faces=faces[:,::-1]
indices = np.rint((v-origin)/STEP).astype(int)
local = D[tuple(indices.T)]
w = np.zeros((len(v),len(BONES)))
for i,b in enumerate(owners):
    w[:,b]+=np.exp((local.min(axis=1)-local[:,i])/.043)
for side,sign in [("L",-1),("R",1)]:
    region=np.exp(-((v[:,1]-.76)/.18)**2-((v[:,2]-.27)/.16)**2)*np.clip(sign*v[:,0]/.14,0,1)
    chest=BONES.index("chest")
    transfer=w[:,chest]*region*.68
    w[:,chest]-=transfer
    w[:,BONES.index("blade"+side)]+=transfer
j=np.argsort(w,axis=1)[:,-4:]
w=np.take_along_axis(w,j,axis=1)
w/=w.sum(axis=1)[:,None]


def inner_ear(p):
    x,y,z=p.T
    t=np.clip((y-1.221)/.215,0,1)
    cz=.591-.044*t
    radius=((np.abs(x)-(.199+.045*t))/(.062*np.sqrt(1-t)+.003))**2+((y-1.350)/.067)**2
    front=np.clip((z-cz)*70,0,1)*np.clip((cz+.080-z)*70,0,1)
    return np.clip((1-radius)*2,0,1)*front


def coat(p):
    x,y,z=p.T
    ax=np.abs(x)
    # Silver shaded tabby: pale undercoat, pencilled flanks, ringed tail and cheek lines.
    back=np.clip((y-.51)*1.7,0,1)
    tone=.92-.17*back
    wave=np.sin(19*z + 6*y + 2*np.sin(6*z) + 1.1*np.cos(7*y))
    tone-=.15*np.maximum(wave,0)**4*np.clip((.55-z)*4,0,1)*np.clip((y-.28)*4,0,1)
    stockings=np.clip((.38-y)*6,0,1)
    tone-=.105*stockings*np.maximum(0,np.sin(49*y+2.4*np.cos(8*z)))**3
    forehead=np.exp(-((z-.78)/.22)**2)*np.clip((y-1.12)*12,0,1)
    # The paired brow stripes converge above the nose, then sweep round the crown.
    brow_path=.049+.25*(y-1.16)+.20*(.87-z)
    pencil=np.exp(-((ax-brow_path)/.024)**2)+.72*np.exp(-((ax-brow_path-.096)/.032)**2)
    tone-=.24*forehead*pencil
    cheek=np.exp(-((ax-.264)/.08)**2-((y-1.046)/.106)**2)
    tone-=.21*cheek*np.maximum(0,np.cos(78*y-20*z))**3
    tone-=.17*np.clip((-z-.65)*4,0,1)*(.3+.7*np.maximum(0,np.cos(27*(z-.6*y)))) 
    eye_dist=((ax-.153)/.079)**2+((y-1.108)/.057)**2
    tone-=.21*np.exp(-((eye_dist-1.15)/.72)**2)*np.clip((z-.77)*16,0,1)
    tone+=.10*np.clip((z-.66)*6,0,1)*np.exp(-((y-1.161)/.045)**2)
    tone+=.105*np.exp(-((z-.95)/.13)**2-((y-.979)/.09)**2)
    tone-=.12*np.exp(-((z-.853)/.080)**2-((ax-.070)/.026)**2-((y-1.128)/.105)**2)
    tone-=.065*np.exp(-((ax-.13)/.11)**2-((y-.990)/.07)**2-((z-.88)/.10)**2)
    tone+=.06*np.exp(-((z-.96)/.13)**2)+.06*np.clip((.34-y)*4,0,1)
    ear=inner_ear(p)
    bib=np.exp(-((z-.61)/.21)**2-((y-.77)/.22)**2-((ax)/.22)**2)
    chin=np.exp(-((z-.92)/.14)**2-((y-.93)/.084)**2)
    base=tone[:,None]*np.array([1.008,1.004,1.017])+(bib*.094+chin*.094)[:,None]
    return np.clip(base*(1-ear[:,None])+np.array([.74,.64,.63])*ear[:,None],0,1)

def field_at(p):
    return map_coordinates(sdf, ((np.asarray(p)-origin)/STEP).T, order=1, mode="nearest")


def face_surface(x,y):
    # Fit eyelids and follicles to the actual sculpt, including both whisker pads.
    lo,hi=.72,1.10
    for _ in range(15):
        z=(lo+hi)/2
        if field_at([[x,y,z]])[0]<0: lo=z
        else: hi=z
    return hi


def occlusion(p,n):
    blocked=np.zeros(len(p))
    for radius,weight in [(.035,.22),(.08,.26),(.16,.26)]:
        d=field_at(p+n*radius)
        blocked+=np.clip(1-d/radius,0,1)*weight
    return (1-blocked*.46)[:,None]

colors=coat(v)*occlusion(v,normal)
chunks=[]
def store(pos,norm,col,js,ws,tri):
    chunks.append((np.asarray(pos),np.asarray(norm),np.asarray(col),np.asarray(js),np.asarray(ws),np.asarray(tri)))

store(v,normal,colors,j,w,faces)
skin_count=len(faces)

# Short guard hairs follow the flanks and grow radially out of the muzzle.
area=np.linalg.norm(area,axis=1)
fi=rng.choice(len(faces),size=32000,p=area/area.sum())
tri=faces[fi]
bary=rng.dirichlet([1,1,1],len(fi))
p=np.einsum("ij,ijk->ik",bary,v[tri])
n=unit(np.einsum("ij,ijk->ik",bary,normal[tri]))
x,y,z=p.T
eye_zone=((np.abs(x)-.153)/.112)**2+((y-1.108)/.085)**2
mask=(y>.067)&(inner_ear(p)<.55)&~((z>.79)&(eye_zone<1.05))
p,n,tri,bary=p[mask],n[mask],tri[mask],bary[mask]
x,y,z=p.T
direction=np.stack([x*.65,-.26-np.clip((z-.46)*2,0,1)*.4,-.8*np.ones_like(x)],axis=1)
legs=np.clip((.46-y)*4,0,1)[:,None]
direction=direction*(1-legs)+np.array([0.,-1.,-.11])*legs
ruff=np.clip((z-.30)*4,0,1)*np.clip((.99-y)*5,0,1)
direction=direction*(1-ruff[:,None])+np.stack([x,-np.ones_like(x),-.18*np.ones_like(x)],1)*ruff[:,None]
direction[z<-.73]=[0,.8,-.28]
direction[y>1.32]=[0,.8,-.25]
tangent=unit(direction-n*np.sum(direction*n,axis=1)[:,None])
side=unit(np.cross(tangent,n))*rng.uniform(.0014,.0034,(len(n),1))
length=rng.uniform(.010,.035,(len(n),1))
length[z>.75]*=.32
length[y<.19]*=.45
start=p-n*.001
tip=p+(tangent*.78+n*.56)*length
pos=np.stack([start-side,start+side,tip],axis=1)
shade=coat(p)*occlusion(p,n)*rng.uniform(.90,1.07,(len(p),1))
# Interpolate the skin at each hair root so tufts follow bent elbows and neck folds.
root_weights=np.zeros((len(tri),len(BONES)),dtype=np.float32)
for corner in range(3):
    ids=tri[:,corner]
    np.add.at(root_weights,(np.arange(len(tri))[:,None],j[ids]),w[ids]*bary[:,corner,None])
hair_joints=np.argsort(root_weights,axis=1)[:,-4:]
hair_weights=np.take_along_axis(root_weights,hair_joints,axis=1)
hair_weights/=hair_weights.sum(axis=1,keepdims=True)
coat_vertices=len(v)+pos.size//3
store(pos.reshape(-1,3),n.repeat(3,axis=0),
      np.stack([shade*.92,shade*.92,np.minimum(shade*1.12,1)],axis=1).reshape(-1,3),
      hair_joints.repeat(3,axis=0),hair_weights.repeat(3,axis=0),np.arange(len(p)*3).reshape(-1,3))


def detail(points, triangles, colors, bone):
    points=np.asarray(points)
    triangles=np.asarray(triangles)
    normals=np.zeros_like(points)
    cross=np.cross(points[triangles[:,1]]-points[triangles[:,0]],points[triangles[:,2]]-points[triangles[:,0]])
    for i in range(3):
        np.add.at(normals,triangles[:,i],cross)
    js=np.zeros((len(points),4));js[:,0]=BONES.index(bone)
    ws=np.zeros_like(js);ws[:,0]=1
    store(points,unit(normals),np.broadcast_to(colors,points.shape),js,ws,triangles)


def swept_line(points, radii, color, bone="head", sides=6):
    points=np.asarray(points)
    tang=unit(np.gradient(points,axis=0))
    axis=np.tile([0.,1.,0.],(len(points),1))
    axis[np.abs(tang[:,1])>.95]=[1,0,0]
    u=unit(np.cross(tang,axis));vv=np.cross(tang,u)
    ang=np.arange(sides)*2*np.pi/sides
    ring=points[:,None,:]+np.asarray(radii)[:,None,None]*(np.cos(ang)[None,:,None]*u[:,None,:]+np.sin(ang)[None,:,None]*vv[:,None,:])
    a=(np.arange(len(points)-1)[:,None]*sides+np.arange(sides)).ravel()
    b=a//sides*sides+(a+1)%sides
    detail(ring.reshape(-1,3),np.vstack([np.stack([a,b,a+sides],1),np.stack([b,b+sides,a+sides],1)]),color,bone)

# Build a convex almond-shaped cornea and pigmented iris inside the lid margins.
for s,side in [(-1,"L"),(1,"R")]:
    center=np.array([s*.147,1.108,.870])
    forward=unit(np.array([s*.40,.05,.915]))
    right=unit(np.cross([0.,1.,0.],forward)); up=np.cross(forward,right)
    rings,segments=24,96
    a=np.linspace(0,2*np.pi,segments,endpoint=False)
    def eye(r,angle):
        xx=np.cos(angle)*r
        yy=np.sin(angle)*r*(1-.26*np.abs(xx))
        base=center+right*(.076*xx)+up*(.048*yy+s*.008*xx)
        base[2]=face_surface(base[0],base[1])+.0035
        return base+forward*(.016*(1-r*r))
    pts=[];cols=[];faces_eye=[]
    for i in range(rings+1):
        r=max(.001,i/rings)
        for k,angle in enumerate(a):
            pts.append(eye(r,angle))
            xx,yy=np.cos(angle)*r,np.sin(angle)*r
            pigment=.5+.34*np.sin(37*angle+.8*np.sin(11*angle)+7*r)+.16*np.sin(71*angle-8*r)
            # Golden-green inner iris, cooler outer rim, shadow under the upper lid.
            rim=np.clip((r-.77)/.23,0,1)
            inner=np.exp(-((r-.44)/.22)**2)
            col=np.array([.42+.13*inner,.53+.05*inner,.36]) + pigment*np.array([.19,.16,.12])
            col*=1-.34*rim-.15*max(0,yy)
            pupil=np.clip((1.03-((xx/.34)**2+(yy/.79)**2))*6,0,1)
            col=col*(1-pupil)+np.array([.041,.048,.047])*pupil
            glint=np.exp(-(((xx+.24)/.115)**2+((yy-.31)/.102)**2)*1.45)
            col=col*(1-glint)+np.array([.99,.99,.97])*glint
            cols.append(col)
            if i:
                b=(i-1)*segments+k;c=(i-1)*segments+(k+1)%segments
                faces_eye.extend([(b,b+segments,c),(c,b+segments,c+segments)])
    detail(pts,faces_eye,cols,"eye"+side)
    for upper in [True,False]:
        arc=np.linspace(0,np.pi,33)*(1 if upper else -1)
        margin=[.27,.25,.22] if upper else [.43,.40,.35]
        swept_line([eye(1,a) for a in arc],.001+.0017*np.abs(np.sin(arc)),margin,"eye"+side)
    # Muzzle follicles and tapered whiskers.
    for i in range(6):
        base=np.array([s*(.097+.020*(i%3)),.977+.018*(i//3),0])
        base[2]=face_surface(base[0],base[1])+.002
        t=np.linspace(0,1,12)
        line=base+np.stack([s*(.20+.031*(i%3))*t,.068*(i-2.4)/3*t-.030*t*t,.022*t-.090*t*t],axis=1)
        swept_line(line,.0019*(1-.87*t),[.90,.89,.86])
    for k in range(3):
        x=s*(.184+.017*k); y=1.173+.007*k
        t=np.linspace(0,1,10)
        points=np.stack([x+s*(.051+.011*k)*t,
                         y+(.087-.012*k)*t+.016*np.sin(np.pi*t),
                         face_surface(x,y)+.005+.056*t-.021*t*t],axis=1)
        swept_line(points,.0013*(1-.90*t),[.85,.83,.80])
    t=np.linspace(0,1,12)
    mouth_x=s*(.002+.068*t);mouth_y=.962-.010*np.sin(t*np.pi*.90)-.009*t
    swept_line(np.stack([mouth_x,mouth_y,[face_surface(x,y)+.0015 for x,y in zip(mouth_x,mouth_y)]],1),
               .0015+.0008*np.sin(t*np.pi),[.46,.40,.39])
# Domed nose leather. Each nostril has a small recessed crescent above the lip.
count=48
pts=[]; cols=[]; nose_faces=[]
for row in range(9):
    r=max(.001,row/8)
    for i,angle in enumerate(np.arange(count)*2*np.pi/count):
        u,vv=r*np.cos(angle),r*np.sin(angle)
        x=.045*u*(1+.38*vv)
        y=1.016+.024*vv-.003*np.exp(-(u/.21)**2)*max(0,vv)
        groove=np.exp(-((abs(u)-.61)/.19)**2-((vv+.04-.35*(abs(u)-.61))/.18)**2)
        z=face_surface(x,y)+.003+.014*(1-r*r)-.004*groove
        pts.append([x,y,z])
        cols.append(np.array([.65,.45,.45])*(1-.39*groove-.16*r+.08*vv))
        if row:
            a=(row-1)*count+i;b=(row-1)*count+(i+1)%count
            nose_faces.extend([(a,a+count,b),(b,a+count,b+count)])
detail(pts,nose_faces,cols,"head")
ys=[.995,.979,.961]
swept_line([[0,y,face_surface(0,y)+.002] for y in ys],[.0025,.002,.002],[.36,.28,.28])
for sign in [-1,1]:
    # A slim lash line remains on the fur when the mobile cornea retracts.
    arc=np.linspace(0,1,25)
    xx=sign*(.085+.126*arc); yy=1.113-.011*np.sin(np.pi*arc)+.007*arc
    swept_line([[x,y,face_surface(x,y)+.001] for x,y in zip(xx,yy)],
               .001+.0019*np.sin(np.pi*arc),[.28,.24,.22])
    for row in range(2):
        for k in range(4):
            x=sign*(.077+.020*k+.006*row);y=.987+.013*row-.004*k
            z=face_surface(x,y)
            swept_line([[x-.002,y,z+.002],[x+.002,y,z+.002]],[.0024,.0024],[.49,.46,.46])

def coat_uv(points):
    # Flank hairs point towards the rump. The ruff and stockings grow downwards,
    # while the short hairs on the face fan away from the whisker pads.
    x,y,z=points.T
    flank=np.stack([-.94*z+.22*x-.24*y,y+.38*x-.13*z],axis=1)
    downward=np.stack([-y+.09*z,x+.45*z],axis=1)
    # The face projection stays signed across the bridge, avoiding mirrored texels.
    cheek=np.stack([x+.42*z,y+.75*x*x+.25*z+.020*np.sin(8*x+5*y)],axis=1)
    ruff=np.clip((z-.27)*3,0,1)*np.clip((1.04-y)*6,0,1)
    legs=np.clip((.53-y)*3.4,0,1)
    vertical=np.maximum(ruff,legs)[:,None]
    uv=flank*(1-vertical)+downward*vertical
    face=(np.clip((z-.49)*4,0,1)*np.clip((y-.88)*8,0,1))[:,None]
    return (uv*(1-face)+cheek*face)*1.60


# Interleaved rest-space coat UVs are shared by SceneKit and the reviewer.
dtype=np.dtype([("point","<f4",3),("normal","<f4",3),("color","u1",4),("joints","u1",4),
                ("weights","<f4",4),("uv","<f4",2)])
records=[];indices=[];offset=0
for pos,norm,col,js,ws,tri in chunks:
    rec=np.zeros(len(pos),dtype)
    rec["point"],rec["normal"],rec["joints"],rec["weights"]=pos,norm,js,ws
    rec["uv"]=coat_uv(pos)
    rec["color"][:,:3]=np.rint(np.clip(col,0,1)*255);rec["color"][:,3]=255
    records.append(rec);indices.append(tri+offset);offset+=len(rec)
records=np.concatenate(records)
index=np.concatenate(indices).astype("<u4")
assert np.isfinite(records["point"]).all() and np.allclose(records["weights"].sum(1),1)
assert index.max()<len(records)
OUT.mkdir(parents=True,exist_ok=True)
(OUT/"BritishKitten.mesh").write_bytes(records.tobytes()+index.tobytes())
meta=dict(version=3,vertices=len(records),triangles=len(index),bodyTriangles=skin_count,
          coatVertices=coat_vertices,coatTriangles=skin_count+(coat_vertices-len(v))//3,bones=BONES,parents=PARENTS,origins=ORIGINS,clips=make_clips())
(OUT/"BritishKitten.json").write_text(json.dumps(meta,separators=(",",":")),encoding="utf-8")
# Tileable short fur with longer guard hairs crossing the dense undercoat.
# The coordinates are bound to rest vertices so the markings travel with the skin.
size=512
yy,xx=np.indices((size,size),dtype=float)
grain=rng.normal(size=(size,size))
layers=np.zeros_like(grain)
for sx,sy,amp in [(4.1,.66,.56),(11,1.15,.31),(1.1,.53,.13)]:
    layer=gaussian_filter(grain,(sy,sx),mode="wrap")
    layers+=amp*layer/layer.std()
warp=8*np.sin(xx*2*np.pi/size)+4*np.sin((xx+yy)*4*np.pi/size)
strokes=map_coordinates(layers,[yy+warp,xx],order=1,mode="grid-wrap")
albedo=np.uint8(np.clip(231+strokes*15,171,255))
Image.fromarray(albedo).convert("RGB").save(OUT/"SilverCoat.png")
print(len(v),"body vertices,",len(index),"total triangles,",len(BONES),"bones")
