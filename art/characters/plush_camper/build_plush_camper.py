"""Original plush camper art source. Python 3 + numpy. Outputs editable embedded
 glTF and binary GLB beside this file. Units metres, Y up, front -Z.
 No downloaded assets, textures, or absolute paths are embedded.
"""
import json, math, struct, base64
from pathlib import Path
import numpy as np
out=Path(__file__).resolve().parent
palette={'body':'EEE3CB','clothing':'6B929C','hat':'BB704C','boots':'536B50','thread':'D6AF66'}
def linear(v):return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
materials=[{'name':n,'pbrMetallicRoughness':{'baseColorFactor':[linear(int(c[i:i+2],16)/255) for i in (0,2,4)]+[1],'metallicFactor':0,'roughnessFactor':.95}} for n,c in palette.items()]
g={'asset':{'version':'2.0','generator':'original_plush_camper_python_generator'},'scene':0,'scenes':[{'name':'plush_camper_scene','nodes':[0]}],'nodes':[{'name':'plush_camper','children':[]}],'meshes':[],'materials':materials,'skins':[],'animations':[],'bufferViews':[],'accessors':[]}
buf=bytearray(); render_parts=[]
def acc(a,typ,ctype=5126):
 a=np.asarray(a,dtype={5126:'<f4',5123:'<u2'}[ctype]);buf.extend(b'\0'*((-len(buf))%4));offset=len(buf);buf.extend(a.tobytes());v=len(g['bufferViews']);g['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':a.nbytes});d={'bufferView':v,'componentType':ctype,'count':len(a),'type':typ}
 if typ in ('VEC3','SCALAR'):d.update(min=a.reshape(len(a),-1).min(axis=0).tolist(),max=a.reshape(len(a),-1).max(axis=0).tolist())
 g['accessors'].append(d);return len(g['accessors'])-1
# Definition coordinates use Z-up for concise sculpting; convert to glTF Y-up.
def cv(v):return np.array([v[0],v[2],v[1]],dtype=float)
bones={'root':((0,0,0),None),'hips':((0,0,.36),'root'),'spine':((0,0,.49),'hips'),'head':((0,0,.67),'spine'),'upper_arm_l':((.16,0,.61),'spine'),'hand_l':((.235,0,.49),'upper_arm_l'),'upper_arm_r':((-.16,0,.61),'spine'),'hand_r':((-.235,0,.49),'upper_arm_r'),'thigh_l':((.085,0,.37),'hips'),'foot_l':((.085,0,.22),'thigh_l'),'thigh_r':((-.085,0,.37),'hips'),'foot_r':((-.085,0,.22),'thigh_r'),'hat_socket':((0,0,.91),'head'),'hair_socket':((0,.01,.84),'head'),'backpack_socket':((0,.10,.54),'spine')}
ids={n:i+1 for i,n in enumerate(bones)};world={n:cv(v[0]) for n,v in bones.items()}
for name,(pos,parent) in bones.items():
 g['nodes'].append({'name':name,'translation':(world[name]-(world[parent] if parent else 0)).tolist(),'children':[]})
 g['nodes'][ids[parent] if parent else 0]['children'].append(ids[name])
ib=[]
for name in bones:
 m=np.eye(4);m[:3,3]=-world[name];ib.append(m.T.flatten())
g['skins'].append({'name':'camper_skin','joints':list(ids.values()),'skeleton':ids['root'],'inverseBindMatrices':acc(ib,'MAT4')})
def ellipsoid(name,loc,scale,material,bone,segments=10,rings=6):
 segments=min(segments,12);rings=min(rings,8)
 verts=[];norm=[];faces=[]
 # single poles and latitude rings, no degenerate triangles
 raw=[(0,0,1)]
 for j in range(1,rings):
  a=math.pi*j/rings
  for i in range(segments):
   b=2*math.pi*i/segments;raw.append((math.sin(a)*math.cos(b),math.sin(a)*math.sin(b),math.cos(a)))
 raw.append((0,0,-1))
 for r in raw:
  verts.append(cv(np.array(loc)+np.array(r)*scale));n=cv(np.array(r)/scale);norm.append(n/np.linalg.norm(n))
 for i in range(segments):faces.append((0,1+i,1+(i+1)%segments))
 for j in range(rings-2):
  for i in range(segments):
   a=1+j*segments+i;b=1+j*segments+(i+1)%segments;c=a+segments;d=b+segments;faces.extend([(a,c,b),(b,c,d)])
 bottom=len(raw)-1;start=1+(rings-2)*segments
 for i in range(segments):faces.append((start+i,bottom,start+(i+1)%segments))
 # ensure winding points outwards after axis conversion
 for k,f in enumerate(faces):
  a,b,c=[verts[q] for q in f]
  if np.dot(np.cross(b-a,c-a),sum((norm[q] for q in f)))<0:faces[k]=(f[0],f[2],f[1])
 joints=np.zeros((len(verts),4),dtype=np.uint16);joints[:,0]=list(bones).index(bone);weights=np.zeros((len(verts),4));weights[:,0]=1
 prim={'attributes':{'POSITION':acc(verts,'VEC3'),'NORMAL':acc(norm,'VEC3'),'JOINTS_0':acc(joints,'VEC4',5123),'WEIGHTS_0':acc(weights,'VEC4')},'indices':acc(np.array(faces).flatten(),'SCALAR',5123),'material':list(palette).index(material)}
 mesh=len(g['meshes']);g['meshes'].append({'name':name+'_mesh','primitives':[prim]});node=len(g['nodes']);g['nodes'].append({'name':name,'mesh':mesh,'skin':0});g['nodes'][0]['children'].append(node);render_parts.append((name,np.array(verts),np.array(faces),material,bone))
ellipsoid('torso',(0,0,.51),(.175,.115,.19),'clothing','spine')
ellipsoid('head',(0,-.014,.785),(.18,.145,.16),'body','head',16,10)
ellipsoid('nose',(0,-.157,.765),(.025,.024,.021),'body','head',8,6)
for side,x in [('l',1),('r',-1)]:
    ellipsoid('ear_'+side,(x*.171,-.015,.78),(.028,.026,.045),'body','head',8,6)
    ellipsoid('sleeve_'+side,(x*.19,0,.555),(.068,.075,.10),'clothing','upper_arm_'+side)
    ellipsoid('mitten_'+side,(x*.244,-.007,.433),(.052,.052,.071),'body','hand_'+side)
    ellipsoid('thumb_'+side,(x*.215,-.040,.449),(.026,.025,.036),'body','hand_'+side,8,6)
    ellipsoid('trouser_'+side,(x*.085,0,.295),(.069,.076,.14),'hat','thigh_'+side)
    ellipsoid('boot_'+side,(x*.085,-.027,.091),(.075,.113,.091),'boots','foot_'+side)
    ellipsoid('eye_'+side,(x*.061,-.163,.802),(.012,.008,.019),'boots','head',8,6)
    for i in range(3):
        ellipsoid('cheek_stitch_'+side+'_'+str(i),(x*(.09+i*.012),-.137,.764),(.004,.005,.009),'thread','head',6,4)
# Stitched smile made of short raised thread segments.
for i in range(7):
    x=(i-3)*.010
    ellipsoid('smile_stitch_'+str(i),(x,-.163,.739+.25*abs(x)),(.006,.004,.0035),'boots','head',6,4)
ellipsoid('hair',(0,.012,.874),(.177,.138,.087),'boots','hair_socket',12,8)
ellipsoid('hair_lock',(.105,-.124,.868),(.06,.03,.055),'boots','hair_socket',8,6)
ellipsoid('hat',(0,.018,.934),(.178,.143,.066),'hat','hat_socket',16,8)
ellipsoid('hat_brim',(0,-.102,.916),(.19,.116,.018),'hat','hat_socket',12,6)
ellipsoid('hat_badge',(0,-.127,.954),(.024,.009,.022),'thread','hat_socket',8,6)
ellipsoid('backpack',(0,.142,.525),(.125,.07,.146),'hat','backpack_socket')
ellipsoid('backpack_pocket',(0,.202,.49),(.094,.025,.065),'thread','backpack_socket',10,6)
for side,x in [('l',1),('r',-1)]:
    ellipsoid('strap_'+side,(x*.105,-.095,.56),(.018,.015,.12),'thread','spine',8,6)
for i in range(7):
    ellipsoid('shirt_seam_'+str(i),(-.09+i*.03,-.095,.40),(.009,.006,.003),'thread','spine',6,4)


def quat(axis,angle):
 q=[0.,0.,0.,math.cos(angle/2)];q[axis]=math.sin(angle/2);return q
clips={'idle':60,'walk':30,'wave':60,'sit':45,'carry':60}
for name,end in clips.items():
 anim={'name':name,'samplers':[],'channels':[],'extras':{'fps':30,'frame_start':0,'frame_end':end,'loop':name in ('idle','walk','carry')}}
 times=acc(np.arange(end+1)/30,'SCALAR');tracks={}
 for bone in bones:
  rot=[];trans=[]
  for f in range(end+1):
   t=f/end;p=t*2*math.pi;axis=0;angle=0.;shift=np.zeros(3)
   if name in ('idle','carry'):
    if bone=='spine':angle=.015*math.sin(p)
    if bone=='head':axis=1;angle=.025*math.sin(p)
   if name=='walk':
    sign=1 if bone.endswith('_l') else -1
    if bone.startswith('thigh'):angle=sign*.40*math.sin(p)
    if bone.startswith('foot'):angle=-max(0,-sign*math.sin(p))*.35
    if bone.startswith('upper_arm'):angle=-sign*.27*math.sin(p)
    if bone=='hips':shift[1]=.009*(1-math.cos(p*2))
   if name=='wave':
    e=max(0,min(1,t*5,(1-t)*5))
    if bone=='upper_arm_r':axis=2;angle=-2.35*e
    if bone=='hand_r':angle=.45*math.sin(p*3)*e
    if bone=='head':axis=2;angle=-.08*e
   if name=='sit':
    e=min(1,t*2);e=e*e*(3-2*e)
    if bone=='hips':shift[1]=-.08*e
    if bone.startswith('thigh'):angle=1.35*e
    if bone.startswith('foot'):angle=-1.3*e
    if bone.startswith('upper_arm'):angle=.35*e
   if name=='carry':
    if bone.startswith('upper_arm'):angle=1.0
    if bone.startswith('hand'):angle=.25
   rot.append(quat(axis,angle));parent=bones[bone][1];trans.append(world[bone]-(world[parent] if parent else 0)+shift)
  for path,values,typ in [('rotation',rot,'VEC4'),('translation',trans,'VEC3')]:
   ai=acc(values,typ);si=len(anim['samplers']);anim['samplers'].append({'input':times,'output':ai,'interpolation':'LINEAR'});anim['channels'].append({'sampler':si,'target':{'node':ids[bone],'path':path}})
 g['animations'].append(anim)
triangles=sum(len(p[2]) for p in render_parts)
assert triangles<5000,triangles
positions=np.concatenate([p[1] for p in render_parts]);bounds=[positions.min(0).tolist(),positions.max(0).tolist()]
g['buffers']=[{'byteLength':len(buf)}]
js=json.dumps(g,separators=(',',':')).encode();js+=b' '*((-len(js))%4);binary=bytes(buf)+b'\0'*((-len(buf))%4)
glb=struct.pack('<III',0x46546c67,2,12+8+len(js)+8+len(binary))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(binary),0x004e4942)+binary
(out/'plush_camper.glb').write_bytes(glb)
g['buffers'][0]['uri']='data:application/octet-stream;base64,'+base64.b64encode(buf).decode()
(out/'plush_camper.gltf').write_text(json.dumps(g,indent=2)+'\n')
manifest={'triangles':triangles,'height_m':bounds[1][1]-bounds[0][1],'bounds':bounds,'fps':30,'animations':{n:{'frame_start':0,'frame_end':f,'samples':f+1,'duration_seconds':f/30,'loop':n in ('idle','walk','carry')} for n,f in clips.items()},'palette':palette,'accessory_bones':{'hair':'hair_socket','hat':'hat_socket','backpack':'backpack_socket'},'source':'plush_camper.gltf','generator':'build_plush_camper.py'}
(out/'asset_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest,indent=2))
