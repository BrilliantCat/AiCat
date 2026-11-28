"""Bind hierarchy and baked local transforms shared by the app and the model reviewer."""
import numpy as np
from scipy.spatial.transform import Rotation

BONES, ORIGINS, PARENTS = [], [], []
def bone(name, parent, position):
    PARENTS.append(BONES.index(parent) if parent else -1)
    BONES.append(name)
    ORIGINS.append(list(position))

bone("pelvis",None,(0,.68,-.35))
bone("spine","pelvis",(0,.70,-.14))
bone("chest","spine",(0,.73,.24))
bone("neck","chest",(0,.81,.38))
bone("head","neck",(0,1.05,.61))
for s,side in [(-1,"L"),(1,"R")]:
    bone("ear"+side,"head",(s*.182,1.23,.59))
    bone("eye"+side,"head",(s*.147,1.108,.870))
TAIL=[(0,.70,-.59),(.018,.68,-.78),(.044,.71,-.98),(.083,.81,-1.15),
      (.113,.96,-1.25),(.132,1.13,-1.27),(.119,1.27,-1.22)]
for i,p in enumerate(TAIL[:-1]):
    bone("tail"+str(i),"pelvis" if i==0 else "tail"+str(i-1),p)
LEGS={}
for s,side in [(-1,"L"),(1,"R")]:
    for front in [True,False]:
        x=s*(.163 if front else .168)
        yz=[(.705,.345),(.412,.255),(.142,.349),(.069,.371)] if front else [
            (.684,-.394),(.441,-.307),(.274,-.523),(.069,-.487)]
        label=("fore" if front else "hind")+side
        points=LEGS[label]=[(x,y,z) for y,z in yz]
        base="chest" if front else "pelvis"
        if front:
            bone("blade"+side,base,(x*.85,.85,.20))
            base="blade"+side
        for i,p in enumerate(points):
            bone(label+str(i),base if i==0 else label+str(i-1),p)

N=len(BONES)
bind=np.array(ORIGINS)
local=bind.copy()
for i,parent in enumerate(PARENTS):
    if parent>=0:local[i]-=bind[parent]


def frame(motion,phase):
    t=phase*2*np.pi
    wave=np.sin(t);pulse=(1-np.cos(t))*.5
    angles=np.zeros((N,3))
    root=np.zeros(3)
    def angle(name,xyz): angles[BONES.index(name)]=xyz
    closed=1.
    angle("neck",[-.028*wave,.055*wave,0])
    angle("earL",[0,-.05*pulse,-.06*pulse])
    feet={name:np.array(points[-1]) for name,points in LEGS.items()}
    wrist_pitch={name:0.0 for name in LEGS}
    pad_pitch=wrist_pitch.copy()
    def ease(start,end):
        u=np.clip((phase-start)/(end-start),0,1)
        return u*u*(3-2*u)
    curl=0.
    root[1]=.006*wave
    if motion in ("walk","trot"):
        running=motion=="trot"
        root[:]=[.017*np.sin(t+.45),-.021+(.038 if running else .014)*np.cos(2*t-.22),0]
        angle("pelvis",[.018*np.cos(2*t),.038*wave,.024*np.sin(t+.45)])
        angle("spine",[.058*np.sin(2*t-.32) if running else -.012*np.sin(2*t),-.065*wave,-.040*np.sin(t+.45)])
        angle("chest",[-.016*np.cos(2*t),.042*wave,.028*np.sin(t-.25)])
        angle("neck",[.025*np.cos(2*t-.55),-.022*wave,-.017*np.sin(t)])
        # Lateral-sequence walk: each hind foot precedes the forefoot on that side.
        offsets=[("foreL",0),("hindL",.5 if running else .22),("foreR",.5),("hindR",0 if running else .72)]
        for label,offset in offsets:
            step=(phase+offset)%1
            contact=.48 if running else .60
            travel=1.38*.54 if running else .58*.8
            reach=travel*contact
            if step<contact:
                feet[label][2]+=reach*.5-travel*step
            else:
                swing=(step-contact)/(1-contact)
                smooth=swing*swing*(3-2*swing)
                # Same velocity at toe-off and touchdown as the planted foot.
                feet[label][2]+=-reach*.5+reach*smooth-travel*(1-contact)*swing*(1-swing)*(1-2*swing)
                feet[label][1]+=(.13 if running else .085)*np.sin(np.pi*swing)**2
                lift=np.sin(np.pi*swing)**2
                wrist_pitch[label]=.32*lift
                pad_pitch[label]=.28*lift*np.cos(np.pi*swing)
            if label.startswith("hind"):
                # Extend the hock at push-off, then draw the heel up as the paw swings.
                toe_off=np.sin(np.pi*np.clip((step-contact+.22)/.40,0,1))**2
                wrist_pitch[label]=.28*toe_off-.13*np.sin(2*np.pi*step)
                if step>=contact:
                    feet[label][1]+=.024*np.sin(np.pi*swing)**2
    elif motion=="scratch":
        # Solve each paw target before skinning. The planted pads never rotate through the rug.
        root[:]=[.012*wave,-.10,.03]
        angle("spine",[-.05,0,0]);angle("chest",[.22,.025*wave,0])
        angle("neck",[.14,0,0]);angle("head",[-.13,.035*wave,0])
        for label in ("hindL","hindR"):
            feet[label][1]+=.006
        for i,label in enumerate(["foreL","foreR"]):
            u=(phase+i*.5)%1
            swing=u>=.54
            f=(u-.54)/.46 if swing else u/.54
            smooth=f*f*(3-2*f)
            feet[label][2]+=.13+.19*(smooth if swing else 1-smooth)
            feet[label][1]+=.012+(.078*np.sin(np.pi*f)**2 if swing else 0)
    elif motion in ("sleep","settle","curl"):
        entering=motion=="settle"
        haunch=ease(.03,.55) if entering else 1
        chest=ease(.24,.76) if entering else 1
        head=ease(.47,.93) if entering else 1
        curl=ease(.27,1) if entering else 1
        breath=0 if entering else wave
        root[:]=[0,-.325*haunch+.004*breath,.028*chest]
        # The chest stays up as the haunches fold. The chin and lids settle last.
        angle("spine",[-.39*haunch+.45*chest,0,0])
        angle("chest",[.11*chest+.012*breath,.08*chest,0])
        angle("neck",[.44*head,.37*head,-.12*head])
        angle("head",[.20*head,.30*head,-.16*head])
        closed=1-.965*(ease(.60,.94) if entering else 1)
        if motion=="curl":
            closed=.84
            angle("neck",[.30,.39+.12*pulse,-.08])
            angle("head",[.10,.32+.10*pulse,-.07])
        for label,p in feet.items():
            if label.startswith("hind"):
                tuck=ease(.03,.51) if entering else 1
                p[2]+=.15*tuck
                wrist_pitch[label]=-.58*tuck
            else:
                delay=.12 if label.endswith("R") else 0
                tuck=ease(.28+delay,.70+delay) if entering else 1
                p[2]+=.13*tuck
            if entering: p[1]+=.042*np.sin(np.pi*tuck)**2
    elif motion in ["eat","pushUp","plank","yoga","stretch","breath","shoulders"]:
        if motion=="eat":
            # Sniff between bites, then lower the muzzle into the centre of the saucer.
            sniff=max(0,np.cos(t))**6
            root[1]=-.073
            angle("spine",[.23,0,0]);angle("chest",[.21,0,0])
            angle("neck",[.63+.028*np.sin(2*t)-.14*sniff,0,0])
            angle("head",[.30-.10*sniff,.026*wave,0])
        elif motion=="breath":
            root[1]=-.045+.03*pulse
            angle("chest",[-.13*pulse,0,0]);angle("head",[-.06*pulse,0,0])
        elif motion=="shoulders":
            root[:]=[.022*np.sin(t),-.05+.031*wave,0]
            angle("chest",[-.10*wave,0,.15*np.cos(t)])
            angle("neck",[.045*wave,0,-.07*np.cos(t)])
        elif motion=="stretch":
            root[1]=-.04-.09*pulse
            angle("spine",[.12+.14*pulse,0,0]);angle("chest",[.06+.20*pulse,0,0])
            angle("neck",[.16,0,0]);angle("head",[-.12,0,0])
            for label,p in feet.items():
                p[2]+=.30 if label.startswith("fore") else -.045
        elif motion=="yoga":
            root[1]=-.07+.055*pulse
            angle("spine",[-.23*pulse,0,0]);angle("chest",[.44*pulse-.10,0,0])
            angle("neck",[.23*pulse,0,0]);angle("head",[.14*pulse-.08,0,0])
        else:
            # Lower, hold, then press back up with all four pads planted.
            depth=(ease(.06,.44)-ease(.56,.92)) if motion=="pushUp" else .62+.025*wave
            root[1]=-.025-.22*depth
            root[2]=.030*depth
            angle("spine",[.035+.095*depth,0,0]);angle("chest",[.055*depth,0,0])
            angle("neck",[.09-.10*depth,0,0])
            for label,p in feet.items():p[2]+=.075 if label.startswith("fore") else -.16
    elif motion in ["computer","think","groom","squat"]:
        root[1]=-.21 if motion!="squat" else -.12-.13*pulse
        angle("spine",[-.29,0,0]);angle("chest",[-.15,0,0])
        angle("neck",[.22,0,0])
        if motion=="squat":
            sit=ease(.06,.43)-ease(.57,.94)
            root[:]=[.006*wave,-.019-.255*sit,-.050*sit]
            angle("spine",[-.31*sit,0,0]);angle("chest",[-.19*sit,0,0])
            angle("neck",[.29*sit,0,0]);angle("head",[.08*sit,0,0])
            for label in feet:
                if label.startswith("hind"): wrist_pitch[label]=-.43*sit
        if motion=="computer":
            angle("neck",[.42,0,0])
            angle("head",[.49+.042*wave,-.035,.024*wave])
            for i,side in enumerate(["L","R"]):
                feet["fore"+side][1:]=[.304+.016*wave*(-1)**i,.59]
        elif motion=="groom":
            feet["foreL"][1:]=[.53+.023*wave,.60];angle("head",[.39+.075*wave,-.35,.13])
        elif motion=="think":angle("head",[-.12,.19,.11])
        for label,p in feet.items():
            if label.startswith("hind") and motion!="squat":p[2]+=.12
    elif motion=="pounce":
        flight=np.sin(np.pi*phase)
        angle("spine",[-.14*flight,0,0]);angle("neck",[.10*flight,0,0])
        for label,p in feet.items():
            fore=label.startswith("fore")
            p[1]+=(.09 if fore else .16)*flight
            p[2]+=(.24 if fore else -.17)*flight
            wrist_pitch[label]=(-.25 if fore else .40)*flight
    elif motion=="play":
        root[1]=-.11+.04*pulse
        feet["foreR"][1:]=[.08+.064*pulse,.38+.27*pulse]
        angle("head",[.25,.14,0])
    elif motion=="purr":
        angle("head",[-.16,.10*wave,-.14*pulse]);closed=.65-.15*pulse
    elif motion=="talk":angle("head",[.07*wave,.06*wave,.04*np.cos(t)])
    elif motion=="scan":angle("head",[-.12,.45*wave,0])
    else:
        # Ears localize the sound first. The eyes/head follow and linger before returning.
        glance=ease(.19,.34)-ease(.61,.83)
        ear_turn=ease(.11,.19)-ease(.59,.78)
        flick=ease(.73,.77)-ease(.77,.84)
        angle("earR",[.032*flick,.34*ear_turn,-.11*flick])
        angle("earL",[-.03*ear_turn,.085*glance,.055*glance])
        angle("chest",[-.012*np.sin(2*t),0,0])
        angle("neck",[.019*np.sin(2*t),.052*glance,0])
        angle("head",[-.044*glance,.20*glance,.074*glance])
    for i in range(len(TAIL)-1):
        sway=1-curl*.9
        tail_phase=0 if motion=="settle" else t
        angle("tail"+str(i),[sway*.032*np.sin(tail_phase-i*.56),
                             sway*.061*np.sin(tail_phase-i*.47),0])
    for side,offset in [("L",0),("R",np.pi)]:
        sweep=.22 if motion=="trot" else .14 if motion in ("scratch","walk") else .025
        angle("blade"+side,[sweep*np.sin(t+offset),0,.025*np.cos(t+offset)])
    # Solve toward room-space pads after the body shifts above the supporting legs.
    rotations=Rotation.from_euler("xyz",angles).as_matrix()
    world=rotations.copy();pos=local.copy();pos[0]+=root
    for i,parent in enumerate(PARENTS):
        if parent>=0:
            pos[i]=pos[parent]+world[parent]@local[i]
            world[i]=world[parent]@rotations[i]
    if curl>0:
        # Aim the links along the outside of the right thigh and forward to the flank.
        # Preserve the bind lengths; only the local bone rotations enter the clip.
        directions=[[.13,-.09,-.10],[.15,-.10,.05],[.079,-.054,.15],
                    [.014,-.012,.18],[-.008,0,.18],[-.018,.011,.14]]
        for k,direction in enumerate(directions):
            i=BONES.index("tail"+str(k))
            parent=world[PARENTS[i]]
            neutral=parent@rotations[i]
            axis=neutral@(np.asarray(TAIL[k+1])-TAIL[k])
            axis/=np.linalg.norm(axis)
            target=np.array(direction)/np.linalg.norm(direction)
            cross=np.cross(axis,target)
            sine=np.linalg.norm(cross)
            if sine>1e-8:
                bend=curl*np.arctan2(sine,np.dot(axis,target))
                world[i]=Rotation.from_rotvec(cross*bend/sine).as_matrix()@neutral
                rotations[i]=parent.T@world[i]
    def pitch(v):return np.arctan2(-v[2],-v[1])
    for label,pts in LEGS.items():
        i=BONES.index(label+"0")
        pts=np.array(pts);seg=np.diff(pts,axis=0)
        wrist=Rotation.from_euler("x",wrist_pitch[label]).as_matrix()
        ankle=feet[label]-wrist@seg[2]
        delta=ankle-pos[i]
        limb_plane=Rotation.from_euler("z",np.arctan2(delta[0],-delta[1])).as_matrix()
        delta=limb_plane.T@delta
        a,b=np.linalg.norm(seg[:2],axis=1)
        dist=np.clip(np.linalg.norm(delta[1:]),abs(a-b)+.001,a+b-.001)
        def acos(v):return np.arccos(np.clip(v,-1,1))
        sign=1 if label.startswith("fore") else -1
        ang=pitch(delta)+sign*acos((a*a+dist*dist-b*b)/(2*a*dist))
        lower=pitch(delta)-sign*acos((b*b+dist*dist-a*a)/(2*b*dist))
        absolute=[ang-pitch(seg[0]),lower-pitch(seg[1]),wrist_pitch[label],pad_pitch[label]]
        parent=world[PARENTS[i]]
        for k,value in enumerate(absolute):
            desired=Rotation.from_euler("x",value).as_matrix()
            if k<2: desired=limb_plane@desired
            rotations[i+k]=parent.T@desired
            parent=desired
    quats=Rotation.from_matrix(rotations).as_quat()
    return np.round(np.r_[root,closed,quats.ravel()],6).tolist()


def make_clips():
    periods=dict(pounce=.46,scratch=1.04,idle=6.4,walk=.8,trot=.54,sleep=4.2,eat=1.25,groom=1.1,computer=1.0,purr=2.2,
                 play=.95,talk=1.3,think=3.8,scan=3.8,squat=2.2,pushUp=2.2,plank=3.2,
                 yoga=3.6,stretch=4.2,curl=4.8,breath=4.0,shoulders=2.8)
    clips={name:dict(seconds=seconds,frames=[frame(name,i/24) for i in range(24)]) for name,seconds in periods.items()}
    clips["sleep"]["entry"]=dict(seconds=1.85,frames=[frame("settle",i/48) for i in range(49)])
    return clips
