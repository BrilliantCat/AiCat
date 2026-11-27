"""Cut cloth panels on the kitten surface, including interpolated skinning at cuffs."""
import json
from pathlib import Path
import numpy as np

folder = Path(__file__).resolve().parents[1] / "Assets/CatModel"
manifest = json.loads((folder / "BritishKitten.json").read_text())
raw = (folder / "BritishKitten.mesh").read_bytes()
dtype = np.dtype([("p","<f4",3),("n","<f4",3),("c","u1",4),("j","u1",4),("w","<f4",4),("uv","<f4",2)])
v = np.frombuffer(raw, dtype, manifest["vertices"])
triangles = np.frombuffer(raw, "<u4", offset=v.nbytes, count=manifest["bodyTriangles"]*3).reshape(-1,3)
x, y, z = v["p"].T

def bake(name, distance, color, trim):
    positions, normals, colors, joints, weights, indices = [], [], [], [], [], []
    cache = {}
    def vertex(i, j=None):
        if j is None: j=i
        i,j=sorted((int(i),int(j)))
        if (i,j) in cache: return cache[i,j]
        t=0 if i==j else distance[i]/(distance[i]-distance[j])
        p=v["p"][i]*(1-t)+v["p"][j]*t
        n=v["n"][i]*(1-t)+v["n"][j]*t
        n/=max(1e-6,np.linalg.norm(n))
        margin=max(0.,distance[i]*(1-t)+distance[j]*t)
        hem=np.exp(-(margin/.029)**2)
        collar=max(0.,min(1.,(p[1]-.74)*6)) if name=="Hoodie" else 0
        fold=.004*np.sin(28*p[2]+5*p[1])
        p=p+n*(.034+fold+.012*hem+collar*.082*np.exp(-((margin-.065)/.055)**2))
        seam=max(hem,np.exp(-((abs(p[0])-.24)/.011)**2)*.36)
        col=(1-seam)*np.array(color)+seam*np.array(trim)
        if name=="Trousers":
            # A stitched back pocket on each flank and a narrow contrasting waistband.
            pocket=max(abs(p[2]+.49)-.086, abs(p[1]-.72)-.087)
            if abs(p[0])>.16 and pocket<0:
                col=col*.78 + np.array([.09,.10,.11])
                if pocket>-.014: col=np.array([.67,.58,.40])
            if -.235<p[2]<-.20: col*=.70
        col*=.97+.03*np.cos(94*p[1]+8*p[2])
        w=np.zeros(len(manifest["bones"]))
        np.add.at(w,v["j"][i],v["w"][i]*(1-t))
        np.add.at(w,v["j"][j],v["w"][j]*t)
        js=np.argsort(w)[-4:][::-1]
        k=len(positions);cache[i,j]=k
        positions.append(p);normals.append(n);colors.append([*col,1])
        joints.append(js);weights.append(w[js]/w[js].sum())
        return k
    for face in triangles:
        poly=[]
        for a,b in zip(face,np.roll(face,-1)):
            inside=distance[a]>=0
            if inside: poly.append(vertex(a))
            if inside!=(distance[b]>=0): poly.append(vertex(a,b))
        for j in range(1,len(poly)-1): indices.extend((poly[0],poly[j],poly[j+1]))
    if name=="Hoodie":
        # Sew a folded, lined hood from the collar down the back. Its open rim has
        # thickness and a dark inner lining, and follows the same spine skinning.
        torso=v[:int(triangles.max())+1]
        points=torso["p"]
        core=points[(abs(points[:,0])<.09)&(points[:,1]>.75)]
        rings=19
        sides=36
        first=len(positions)
        for layer in range(2):
            for row in range(rings):
                u=row/(rings-1)
                zz=-.14+.46*u
                top=core[abs(core[:,2]-zz)<.055,1].max()
                width=.028+.197*np.sin(u*np.pi*.52)
                for j in range(sides):
                    a=2*np.pi*j/sides
                    xx=np.cos(a)*(width-layer*.009)
                    yy=top+.046+(.035+.058*u-layer*.010)*np.sin(a)-.068*(xx/.235)**2
                    point=np.array([xx,yy,zz-layer*.008*u])
                    idx=np.argmin(np.sum((points-point)**2,axis=1))
                    n=np.array([.55*np.cos(a),np.sin(a),.10]);n/=np.linalg.norm(n)
                    positions.append(point);normals.append(n if layer==0 else -n)
                    col=([.11,.50,.46] if layer==0 else [.04,.20,.21]) if row<rings-2 else [.52,.74,.64]
                    colors.append([*col,1]);joints.append(torso["j"][idx]);weights.append(torso["w"][idx])
        for row in range(rings-1):
            for j in range(sides):
                a=first+row*sides+j;b=first+row*sides+(j+1)%sides
                indices.extend((a,b,a+sides,b,b+sides,a+sides))
                k=rings*sides
                indices.extend((a+k,a+sides+k,b+k,b+k,a+sides+k,b+sides+k))
        for row in (0,rings-1):
            for j in range(sides):
                a=first+row*sides+j;b=first+row*sides+(j+1)%sides;k=rings*sides
                indices.extend((a,a+k,b,b,a+k,b+k))
    parts=[([len(positions),len(indices)],"<u4"),(positions,"<f4"),(normals,"<f4"),(colors,"<f4"),
           (joints,"u1"),(weights,"<f4"),(indices,"<u4")]
    (folder/(name+".cloth")).write_bytes(b"".join(np.asarray(a,dtype=dt).tobytes() for a,dt in parts))

# A diagonal neckline, a shorter underbelly, and openings for the limbs and tail.
neck=.87-(y+.46*(z-.30))
for name,sleeve,hem,c,t in [
    ("Hoodie",.31,-.27,[.10,.51,.49],[.66,.86,.70]),
    ("Vest",.52,-.21,[.78,.42,.12],[.39,.21,.10])]:
    bake(name,np.minimum.reduce([neck+.13, z-hem-.10*np.clip(.7-y,0,1), y-sleeve, .66-z]),c,t)
bake("Trousers",np.minimum.reduce([-.19-z,y-.23,z+.79-.14*np.clip((y-.57)*6,0,1)]),
     [.22,.34,.50],[.58,.70,.78])
