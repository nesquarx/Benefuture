"""Viewers of the tiled basemap (LI.52, LI.53): vector map and raster, online and offline.

Vector (the map, for looking at something in particular): canvas code of its own over MVT tiles read from a PMTiles archive
(range requests when online, the archive embedded when offline), coloured at view time from the levels file. Map conventions
(LI.53): search by name or id with fly-to, click to select with an information panel (domain, parents, levels and, where the
levels file discloses them, evidence rows), hover highlight, labels where they fit, channel toggles, legend, zoom and position
indicator, and the view in the URL hash (`#z=..&x=..&y=..&sel=..&ch=rgb`), restored on load.

Raster (the quick look): a PNG pyramid rendered here from the same tiles and levels, covering 1x to 4x only (zoom levels 0 to 2:
a 256 px to a 1024 px disc); anything deeper is the vector version's job.

Disclosure (`disclose`) decides what the levels file holds: none, levels only; summary, labels and parents; full, evidence rows.
The tiles are public either way.

Recalibration: vector pages recolour from a migrated levels file; raster pyramids are re-rendered (`raster_pyramid`).
"""
import base64
import io
import json
import math
from html import escape

import numpy as np
from PIL import Image, ImageDraw

from . import tiles as T

RASTER_MAXZOOM = 2
DISCLOSURES = ("none", "summary", "full")


def disclose(lf, ctx, spec, disclosure):
    """The levels file at a disclosure: summary adds labels and parents, full adds the evidence rows behind each domain."""
    from . import interactive as it
    if disclosure not in DISCLOSURES:
        raise ValueError(f"disclosure must be one of {DISCLOSURES}, not {disclosure!r}")
    out = {k: v for k, v in lf.items() if k not in ("labels", "parents", "rows")}
    out["disclosure"] = disclosure
    if disclosure == "none":
        return out
    by = ctx["by"]
    out["labels"] = {i: by[i]["label"] for i in sorted(by)}
    out["parents"] = {i: [l["id"] for l in sorted((l for l in by[i]["links"] if l["rel"] == "upstream"), key=lambda l: (-l["weight"], l["id"]))]
                      for i in sorted(by)}
    if disclosure == "full":
        model = it.build_model(spec, ctx, "full")
        rows = {}
        for idx, lst in model.get("rows", {}).items():
            rows[model["slices"][int(idx)]["id"]] = [{k: x[k] for k in ("t", "k", "d", "c", "v", "b") if k in x} for x in lst[:25]]
        out["rows"] = dict(sorted(rows.items()))
    return out


# ---------- raster ----------

_C = np.arange(256) / 255.0
_LUT = np.where(_C <= 0.04045, _C / 12.92, ((_C + 0.055) / 1.055) ** 2.4)


def _downsample_linear(rgb8, ss):
    """Box-filter an 8-bit sRGB image by ss in linear light (edge pixels keep the light they cover), back to sRGB floats 0-255."""
    n = rgb8.shape[0] // ss
    lin = _LUT[rgb8].reshape(n, ss, n, ss, 3).mean(axis=(1, 3))
    return 255 * np.where(lin <= 0.0031308, 12.92 * lin, 1.055 * np.maximum(lin, 1e-12) ** (1 / 2.4) - 0.055)


def render_tile(archive, lf, z, x, y, ss=2):
    """PNG bytes of one tile, or None when it is all black. Supersampled, then box-filtered; claimed red is drawn as grain."""
    layers = archive.decoded(z, x, y)
    S = T.TILE_PX * ss
    img, claimed = Image.new("RGB", (S, S)), Image.new("RGB", (S, S))
    d, dc, has_claim = ImageDraw.Draw(img), ImageDraw.Draw(claimed), False
    for name in T.LAYERS:
        for f in layers.get(name, []):
            col = T.feature_colour(lf, name, f["tags"], archive.order)
            grain = T.feature_claimed(lf, name, f["tags"], archive.order)
            for ring in f["rings"]:
                pts = [(px * S / T.MVT_EXTENT, py * S / T.MVT_EXTENT) for px, py in ring]
                if any(col):
                    d.polygon(pts, fill=col)
                if grain:
                    dc.polygon(pts, fill=(int(round(255 * grain)), 0, 0))
                    has_claim = True
    out = _downsample_linear(np.asarray(img), ss)
    if has_claim:
        ext = archive.metadata["extent"]
        k = T.ppu(z, ext)
        period = max(2.0, 0.014 * k)
        dot = max(1.0, period * 0.006 / 0.014)
        ii = np.arange(T.TILE_PX)
        gx = ((x * T.TILE_PX + ii) % period) < dot
        gy = ((y * T.TILE_PX + ii) % period) < dot
        mask = (gy[:, None] & gx[None, :])[:, :, None]
        c = np.asarray(claimed.resize((T.TILE_PX, T.TILE_PX), Image.BOX), dtype=np.float64) * mask
        out = 255 - (255 - out) * (255 - c) / 255
    arr = np.clip(np.rint(out), 0, 255).astype(np.uint8)
    if not arr.any():
        return None
    buf = io.BytesIO()
    Image.fromarray(arr, "RGB").save(buf, "PNG", optimize=True)
    return buf.getvalue()


def raster_pyramid(archive, lf, maxzoom=RASTER_MAXZOOM):
    """{(z, x, y): PNG bytes} for zoom 0 to maxzoom (never beyond RASTER_MAXZOOM: raster covers 1x to 4x, LI.53)."""
    if maxzoom > RASTER_MAXZOOM:
        raise ValueError(f"raster stops at zoom {RASTER_MAXZOOM} (4x); deeper is the vector version's job")
    out = {}
    for (z, x, y) in sorted(archive.tiles()):
        if z <= maxzoom and (png := render_tile(archive, lf, z, x, y)):
            out[(z, x, y)] = png
    return out


# ---------- pages ----------

CSS = """
:root{color-scheme:dark;--bg:#0b0b0e;--fg:#e6e6ea;--mut:#9a9aa6;--line:#26262e;--panel:#14141a}
*{box-sizing:border-box}html,body{height:100%;margin:0}
body{background:var(--bg);color:var(--fg);font:14px/1.4 system-ui,sans-serif;display:flex;flex-direction:column}
header{padding:.5rem 1rem;border-bottom:1px solid var(--line);display:flex;gap:1rem;align-items:center;flex-wrap:wrap}
h1{font-size:1rem;margin:0}.note{color:var(--mut);margin:0;font-size:.8rem}
#wrap{flex:1;display:flex;min-height:0}#stage{flex:1;position:relative;min-width:0}
canvas{position:absolute;inset:0;width:100%;height:100%;touch-action:none;cursor:grab;display:block}
aside{width:300px;max-width:42vw;border-left:1px solid var(--line);background:var(--panel);padding:.6rem .8rem;overflow:auto;font-size:.85rem}
aside h2{font-size:.9rem;margin:.8rem 0 .3rem}#info p{margin:.2rem 0}
#search{width:16rem;max-width:60vw;padding:.3rem .5rem;background:#0f0f14;color:var(--fg);border:1px solid var(--line);border-radius:4px}
#results{position:absolute;z-index:3;background:var(--panel);border:1px solid var(--line);list-style:none;margin:0;padding:0;max-height:16rem;overflow:auto}
#results li{padding:.25rem .6rem;cursor:pointer}#results li:hover,#results li.on{background:#22222c}
.sw{display:inline-block;width:.8rem;height:.8rem;margin-right:.4rem;vertical-align:-1px;border-radius:2px}
#pos{position:absolute;left:.5rem;bottom:.5rem;background:#000a;padding:.15rem .5rem;border-radius:4px;font-size:.75rem;color:var(--mut)}
label.ch{margin-right:.7rem;cursor:pointer}
.row{border-top:1px solid var(--line);padding:.3rem 0}.row b{font-weight:600}
@media (max-width:700px){#wrap{flex-direction:column}aside{width:auto;max-width:none;max-height:40vh;border-left:0;border-top:1px solid var(--line)}}
"""

LEGEND = ('<h2>Legend</h2><p><span class="sw" style="background:#f33"></span>red: knowledge and potential</p>'
          '<p><span class="sw" style="background:#3d3"></span>green: demonstrated skill</p>'
          '<p><span class="sw" style="background:#46f"></span>blue: impact</p>'
          '<p>Brighter is a higher level; paler is self-reported; red grain is claimed potential. Rings out from the centre: '
          'sectors, fields, fine domains.</p>')

JS = r"""
(function(){'use strict';
var CFG=JSON.parse(document.getElementById('cfg').textContent),META=CFG.meta,EXT=META.extent,MAXZ=META.maxzoom,TILE=256;
var VEC=CFG.mode==='vector',RMAX=2,LAYERS=['sector','aggregate','field','fine'];
var cv=document.getElementById('c'),ctx=cv.getContext('2d'),posEl=document.getElementById('pos'),info=document.getElementById('info');
var tv=window.__tv={ready:false,idle:false,errors:[],tilesFetched:[],tileBytes:0,selected:null,hover:null,labelsDrawn:0};
window.addEventListener('error',function(e){tv.errors.push(String(e.message))});
window.addEventListener('unhandledrejection',function(e){tv.errors.push(String(e.reason))});
var W=1,H=1,DPR=1,cam={wpx:512,cx:.5,cy:.5},ch={r:true,g:true,b:true},LV=null,LS=[],IDS={},KIND='single',MEM=[],MODE=0,SETS=null,SEL=null,HOV=null,pending=0,anim=false,drawQ=false;
var tiles=new Map(),IDX=META.index||{},LAB={},PAR={},ROWS={};
function rad(d){return d*Math.PI/180}
function wmin(){return VEC?Math.min(W,H)*.5:TILE}
function wmax(){return VEC?TILE*Math.pow(2,MAXZ+3):TILE*4}
function clampCam(){cam.wpx=Math.min(wmax(),Math.max(wmin(),cam.wpx));cam.cx=Math.min(1,Math.max(0,cam.cx));cam.cy=Math.min(1,Math.max(0,cam.cy))}
function fitW(){return VEC?Math.min(W,H):Math.min(1024,Math.max(TILE,Math.min(W,H)))}
function zoomOf(){return Math.log(cam.wpx/TILE)/Math.LN2}
function origin(){return [cam.cx*cam.wpx-W/2,cam.cy*cam.wpx-H/2]}
function tileZ(){return Math.max(0,Math.min(VEC?MAXZ:RMAX,Math.ceil(zoomOf()-1e-9)))}
function viewTiles(z,ox,oy,w,h){var n=Math.pow(2,z),x0=Math.max(0,Math.floor(ox/TILE)),x1=Math.min(n-1,Math.floor((ox+w-1e-9)/TILE)),
 y0=Math.max(0,Math.floor(oy/TILE)),y1=Math.min(n-1,Math.floor((oy+h-1e-9)/TILE)),o=[];
 for(var y=y0;y<=y1;y++)for(var x=x0;x<=x1;x++)o.push([x,y]);return o}
// ---- bytes
function b64(s){var b=atob(s),u=new Uint8Array(b.length);for(var i=0;i<b.length;i++)u[i]=b.charCodeAt(i);return u}
async function gunzip(buf){var ds=new DecompressionStream('gzip'),r=new Response(new Blob([buf]).stream().pipeThrough(ds));return new Uint8Array(await r.arrayBuffer())}
// ---- PMTiles v3 reader
function tileId(z,x,y){var acc=(Math.pow(4,z)-1)/3;for(var a=z-1;a>=0;a--){var s=Math.pow(2,a),rx=(x&s)?s:0,ry=(y&s)?s:0;
 acc+=((3*rx)^ry)*s;if(ry===0){if(rx!==0){x=s-1-x;y=s-1-y}var t=x;x=y;y=t}}return acc}
function readVar(b,o){var n=0,m=1,c;do{c=b[o.i++];n+=(c&127)*m;m*=128}while(c&128);return n}
function parseDir(b){var o={i:0},n=readVar(b,o),e=[],last=0,i;for(i=0;i<n;i++){last+=readVar(b,o);e.push({id:last})}
 for(i=0;i<n;i++)e[i].run=readVar(b,o);for(i=0;i<n;i++)e[i].len=readVar(b,o);
 for(i=0;i<n;i++){var v=readVar(b,o);e[i].off=(v===0&&i>0)?e[i-1].off+e[i-1].len:v-1}return e}
function PM(src){this.src=src;this.dirs=new Map();this.h=null}
PM.prototype.init=async function(){var b=await this.src(0,16384,'hdr'),d=new DataView(b.buffer,b.byteOffset,b.byteLength),q=function(k){return Number(d.getBigUint64(8+8*k,true))};
 this.h={ro:q(0),rl:q(1),mo:q(2),ml:q(3),lo:q(4),ll:q(5),dofs:q(6),dl:q(7)};
 this.root=parseDir(await gunzip(b.subarray(this.h.ro,this.h.ro+this.h.rl)));return this};
PM.prototype.find=async function(z,x,y){var id=tileId(z,x,y),ents=this.root;
 for(var depth=0;depth<4;depth++){var lo=0,hi=ents.length-1,hit=-1;while(lo<=hi){var m=(lo+hi)>>1;if(ents[m].id<=id){hit=m;lo=m+1}else hi=m-1}
  if(hit<0)return null;var e=ents[hit];if(e.run>0){return id<e.id+e.run?e:null}
  var key=e.off;if(!this.dirs.has(key)){this.dirs.set(key,parseDir(await gunzip(await this.src(this.h.lo+e.off,e.len,'dir'))))}ents=this.dirs.get(key)}return null};
PM.prototype.tile=async function(z,x,y){var e=await this.find(z,x,y);if(!e)return null;tv.tileBytes+=e.len;
 return gunzip(await this.src(this.h.dofs+e.off,e.len,'tile'))};
PM.prototype.metadata=async function(){return JSON.parse(new TextDecoder().decode(await gunzip((await this.src(this.h.mo,this.h.ml,'meta')))))};
// ---- MVT decode
function decodeMVT(b){var out={},i=0;
 function vr(){var n=0,m=1,c;do{c=b[i++];n+=(c&127)*m;m*=128}while(c&128);return n}
 function sub(buf){return buf}
 var layers=[];while(i<b.length){var key=vr(),num=key>>3,wt=key&7;if(wt===2){var ln=vr();if(num===3)layers.push([i,i+ln]);i+=ln}else if(wt===0)vr();else throw new Error('wire')}
 layers.forEach(function(r){var name='',keys=[],vals=[],feats=[],j=r[0];
  function v2(){var n=0,m=1,c;do{c=b[j++];n+=(c&127)*m;m*=128}while(c&128);return n}
  while(j<r[1]){var k=v2(),nn=k>>3,w=k&7;if(w===2){var l=v2(),s=j;j+=l;
    if(nn===1)name=new TextDecoder().decode(b.subarray(s,s+l));else if(nn===3)keys.push(new TextDecoder().decode(b.subarray(s,s+l)));
    else if(nn===4){var p=s;p++;var l2=0,m2=1,c2;do{c2=b[p++];l2+=(c2&127)*m2;m2*=128}while(c2&128);vals.push(new TextDecoder().decode(b.subarray(p,p+l2)))}
    else if(nn===2)feats.push([s,s+l])}else if(w===0)v2();else throw new Error('wire')}
  out[name]=feats.map(function(f){var p=f[0],tags=[],geom=[];
   function v3(){var n=0,m=1,c;do{c=b[p++];n+=(c&127)*m;m*=128}while(c&128);return n}
   while(p<f[1]){var k=v3(),n3=k>>3,w3=k&7;if(w3===2){var l=v3(),e=p+l;if(n3===2){while(p<e)tags.push(v3())}else if(n3===4){while(p<e)geom.push(v3())}else p=e}else v3()}
   var props={};for(var t=0;t<tags.length;t+=2)props[keys[tags[t]]]=vals[tags[t+1]];
   var rings=[],cur=null,x=0,y=0,g=0;while(g<geom.length){var cmd=geom[g]&7,cnt=geom[g]>>3;g++;if(cmd===7){rings.push(cur);cur=null;continue}
    for(var c=0;c<cnt;c++){var dx=geom[g],dy=geom[g+1];g+=2;x+=(dx>>>1)^-(dx&1);y+=(dy>>>1)^-(dy&1);if(cmd===1)cur=[];cur.push(x,y)}}
   return {tags:props,rings:rings}})});
 return out}
// ---- sources
var pm=null,rasterSrc=null;
async function bootSource(){
 if(VEC){
  var src;
  if(CFG.source==='offline'){var blob=b64(document.getElementById('blob').textContent);src=async function(o,l){return blob.subarray(o,o+l)}}
  else{var whole=null;src=async function(o,l){if(whole)return whole.subarray(o,o+l);
    var r=await fetch(CFG.urls.tiles,{headers:{Range:'bytes='+o+'-'+(o+l-1)}});var buf=new Uint8Array(await r.arrayBuffer());
    if(r.status===200){whole=buf;return buf.subarray(o,o+l)}return buf}}
  pm=await new PM(src).init();
 }else if(CFG.source==='offline'){rasterSrc=JSON.parse(document.getElementById('blob').textContent)}
}
function getTile(z,x,y){var k=z+'/'+x+'/'+y,t=tiles.get(k);if(t)return t;t={state:0,data:null};tiles.set(k,t);pending++;tv.idle=false;
 tv.tilesFetched.push([z,x,y]);
 var done=function(d){t.data=d;t.state=1;pending--;schedule()},fail=function(e){t.state=2;pending--;if(e)tv.errors.push(String(e));schedule()};
 if(VEC){pm.tile(z,x,y).then(function(b){done(b?decodeMVT(b):null)},fail)}
 else{var im=new Image();im.onload=function(){done(im)};im.onerror=function(){t.state=1;t.data=null;pending--;schedule()};
  if(CFG.source==='offline'){var u=rasterSrc[k];if(u)im.src='data:image/png;base64,'+u;else{t.state=1;pending--;setTimeout(schedule,0)}}
  else im.src=CFG.urls.tiles+k+'.png'}
 return t}
// ---- colour
function clamp01(x){return Math.min(1,Math.max(0,x))}
function rgbv(v){var c=[ch.r?v[0]:0,ch.g?v[1]:0,ch.b?v[2]:0],t=v[3];if(t!==1){var g=(c[0]+c[1]+c[2])/3;c=c.map(function(x){return g+t*(x-g)})}
 return c.map(function(x){return Math.round(255*clamp01(x))})}
function colour(v){return 'rgb('+rgbv(v)+')'}
function lin(c){c/=255;return c<=.04045?c/12.92:Math.pow((c+.055)/1.055,2.4)}
function enc(x){x=clamp01(x);return Math.round(255*(x<=.0031308?12.92*x:1.055*Math.pow(x,1/2.4)-.055))}
var ORD=null;
function members(f){if(!f._m){if(!ORD)ORD=Object.keys(IDX).sort();f._m=f.tags.m.split(',').map(function(i){return ORD[+i]});f._a=f.tags.a.split(',').map(function(x){return x/10000})}return f}
// colour and claimed red of a feature: an aggregate averages its members by area share in linear light
function fcol(f,L){if(L!=='aggregate'){var v=IDS[f.tags.id];return [lit(v)?colour(v):null,v&&ch.r?v[4]:0]}
 members(f);var acc=[0,0,0],cl=0,any=false;
 for(var i=0;i<f._m.length;i++){var v=IDS[f._m[i]];if(!v)continue;if(ch.r)cl+=f._a[i]*v[4];if(!lit(v))continue;any=true;var c=rgbv(v);for(var j=0;j<3;j++)acc[j]+=f._a[i]*lin(c[j])}
 return [any?'rgb('+acc.map(enc)+')':null,cl]}
function lit(v){return v&&((ch.r&&v[0])||(ch.g&&v[1])||(ch.b&&v[2]))}
// ---- drawing
function sx(zt,x,px){return (x+px/4096)/Math.pow(2,zt)*cam.wpx-origin()[0]}
function sy(zt,y,py){return (y+py/4096)/Math.pow(2,zt)*cam.wpx-origin()[1]}
function pathOf(c,zt,x,y,rings){c.beginPath();rings.forEach(function(r){for(var i=0;i<r.length;i+=2){var X=sx(zt,x,r[i]),Y=sy(zt,y,r[i+1]);if(i)c.lineTo(X,Y);else c.moveTo(X,Y)}c.closePath()})}
var gl=null,gc=null;
function drawVector(){
 var z=tileZ(),k=TILE*Math.pow(2,z)/cam.wpx,o=origin(),need=viewTiles(z,o[0]*k,o[1]*k,W*k,H*k),claimed=[];
 need.forEach(function(t){var T0=getTile(z,t[0],t[1]),zt=z,x=t[0],y=t[1];
  while(T0.state!==1&&zt>0){zt--;x>>=1;y>>=1;T0=tiles.get(zt+'/'+x+'/'+y)||{state:0}}
  if(T0.state!==1||!T0.data)return;
  LAYERS.forEach(function(L){(T0.data[L]||[]).forEach(function(f){var fc=fcol(f,L);
   if(!fc[0]&&!fc[1])return;
   if(fc[0]){ctx.fillStyle=fc[0];ctx.strokeStyle=fc[0];ctx.lineWidth=.6;pathOf(ctx,zt,x,y,f.rings);ctx.fill();ctx.stroke()}
   if(fc[1])claimed.push([f,zt,x,y,fc[1]])})})});
 if(claimed.length){if(!gl){gl=document.createElement('canvas');gc=document.createElement('canvas')}
  gl.width=cv.width;gl.height=cv.height;var g=gl.getContext('2d');g.setTransform(DPR,0,0,DPR,0,0);
  claimed.forEach(function(c){g.fillStyle='rgb('+Math.round(255*c[4])+',0,0)';pathOf(g,c[1],c[2],c[3],c[0].rings);g.fill()});
  var ppu=cam.wpx/(2*EXT),P=Math.max(2,Math.round(.014*ppu)),D=Math.max(1,Math.round(P*.006/.014));
  gc.width=P;gc.height=P;var q=gc.getContext('2d');q.fillStyle='#fff';q.fillRect(0,0,D,D);
  var m=document.createElement('canvas');m.width=cv.width;m.height=cv.height;var mc=m.getContext('2d');mc.setTransform(DPR,0,0,DPR,0,0);
  mc.fillStyle=mc.createPattern(gc,'repeat');mc.translate(-(o[0]%P),-(o[1]%P));mc.fillRect(o[0]%P,o[1]%P,W+P,H+P);
  g.setTransform(1,0,0,1,0,0);g.globalCompositeOperation='destination-in';g.drawImage(m,0,0);g.globalCompositeOperation='source-over';
  ctx.save();ctx.setTransform(1,0,0,1,0,0);ctx.globalCompositeOperation='screen';ctx.drawImage(gl,0,0);ctx.restore()}
 // highlight
 [HOV,SEL].forEach(function(id,n){if(!id)return;ctx.strokeStyle=n?'#ffd84a':'#ffffff';ctx.lineWidth=n?2.2:1.4;
  need.forEach(function(t){var T0=tiles.get(z+'/'+t[0]+'/'+t[1]);if(!T0||!T0.data)return;
   LAYERS.forEach(function(L){(T0.data[L]||[]).forEach(function(f){if(f.tags.id===id&&L!=='aggregate'){pathOf(ctx,z,t[0],t[1],f.rings);ctx.stroke()}})})})});
 drawLabels()}
function drawRaster(){
 var z=tileZ(),k=TILE*Math.pow(2,z)/cam.wpx,o=origin(),need=viewTiles(z,o[0]*k,o[1]*k,W*k,H*k);
 ctx.imageSmoothingEnabled=true;
 need.forEach(function(t){var T0=getTile(z,t[0],t[1]);if(T0.state!==1||!T0.data)return;
  var s=cam.wpx/Math.pow(2,z);ctx.drawImage(T0.data,t[0]*s-o[0],t[1]*s-o[1],s,s)})}
function sector(id){var s=IDX[id];if(!s)return null;var a=rad(s[0]+s[1]/2),r=(s[2]+s[3])/2;
 return {wx:.5+r*Math.cos(a)/(2*EXT),wy:.5-r*Math.sin(a)/(2*EXT),s:s,ang:s[0]+s[1]/2}}
function screenOf(id){var c=sector(id);if(!c)return null;var o=origin(),r=cv.getBoundingClientRect();return {x:c.wx*cam.wpx-o[0]+r.left,y:c.wy*cam.wpx-o[1]+r.top}}
var tw={};
function drawLabels(){var ppu=cam.wpx/(2*EXT),o=origin(),fs=11,cand=[];ctx.font=fs+'px system-ui,sans-serif';ctx.textAlign='center';ctx.textBaseline='middle';
 if(LV&&LV.labels){for(var id in IDX){var s=IDX[id],lab=LV.labels[id];if(!lab)continue;
  var arc=(s[2]+s[3])/2*rad(s[1])*ppu,dep=(s[3]-s[2])*ppu;if(arc<fs+2)continue;
  var c=sector(id),X=c.wx*cam.wpx-o[0],Y=c.wy*cam.wpx-o[1];if(X<-50||Y<-50||X>W+50||Y>H+50)continue;
  var w=tw[lab]||(tw[lab]=ctx.measureText(lab).width);if(dep<w+6)continue;
  var a=-rad(c.ang);if(Math.cos(a)<0)a+=Math.PI;
  var bw=w+4,bh=fs+2,hx=(Math.abs(Math.cos(a))*bw+Math.abs(Math.sin(a))*bh)/2,hy=(Math.abs(Math.sin(a))*bw+Math.abs(Math.cos(a))*bh)/2;
  cand.push({id:id,lab:lab,w:w,X:X,Y:Y,a:a,area:arc*dep,box:[X-hx,Y-hy,X+hx,Y+hy]})}}
 cand.sort(function(p,q){return q.area-p.area||(p.id<q.id?-1:1)});var kept=[];
 cand.forEach(function(c){var b=c.box;for(var i=0;i<kept.length;i++){var k=kept[i].box;if(!(b[2]<=k[0]||k[2]<=b[0]||b[3]<=k[1]||k[3]<=b[1]))return}kept.push(c)});
 kept.forEach(function(c){ctx.save();ctx.translate(c.X,c.Y);ctx.rotate(c.a);ctx.fillStyle='#000a';ctx.fillRect(-c.w/2-2,-fs/2-1,c.w+4,fs+2);ctx.fillStyle='#fff';ctx.fillText(c.lab,0,0);ctx.restore()});
 tv.labelsDrawn=kept.length;tv.labelCandidates=cand.length;tv.labelBoxes=kept.map(function(c){return c.box})}
function draw(){drawQ=false;ctx.setTransform(DPR,0,0,DPR,0,0);ctx.globalCompositeOperation='source-over';ctx.fillStyle='#000';ctx.fillRect(0,0,W,H);
 if(CFG.mode==='vector'&&!pm)return;if(VEC&&LV)drawVector();else if(!VEC)drawRaster();
 var z=zoomOf(),e=(cam.cx-.5)*2*EXT,f=-(cam.cy-.5)*2*EXT,r=Math.hypot(e,f),ang=(Math.atan2(f,e)*180/Math.PI+360)%360;
 posEl.textContent='zoom '+z.toFixed(2)+' ('+(cam.wpx/fitW()).toFixed(1)+'x) · centre r '+r.toFixed(3)+', angle '+ang.toFixed(1)+'°';
 if(!pending&&!anim)tv.idle=true;scheduleHash()}
function schedule(){if(drawQ)return;drawQ=true;requestAnimationFrame(draw)}
// ---- hash
var ht=0;
function hashOf(){var h='#z='+zoomOf().toFixed(3)+'&x='+cam.cx.toFixed(5)+'&y='+cam.cy.toFixed(5);if(SEL)h+='&sel='+encodeURIComponent(SEL);
 if(VEC)h+='&ch='+(ch.r?'r':'')+(ch.g?'g':'')+(ch.b?'b':'');return h}
function scheduleHash(){clearTimeout(ht);ht=setTimeout(function(){if(!anim){try{history.replaceState(null,'',hashOf())}catch(e){}}},120)}
function readHash(){var h=location.hash.replace(/^#/,'');if(!h)return false;var p={};h.split('&').forEach(function(kv){var a=kv.split('=');p[a[0]]=decodeURIComponent(a[1]||'')});
 if(p.z===undefined)return false;cam.wpx=TILE*Math.pow(2,+p.z);cam.cx=+p.x;cam.cy=+p.y;if(p.ch!==undefined){ch.r=p.ch.indexOf('r')>=0;ch.g=p.ch.indexOf('g')>=0;ch.b=p.ch.indexOf('b')>=0}
 if(p.sel)SEL=p.sel;return true}
// ---- selection and panel
function esc(s){return String(s).replace(/[&<>"]/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]})}
function name(id){return (LV&&LV.labels&&LV.labels[id])||id}
function select(id){SEL=id;tv.selected=id;panel();schedule();scheduleHash()}
function panel(){if(!info)return;if(!SEL){info.innerHTML='<p>Click a slice to select it, or search for a domain above.</p>';return}
 var v=IDS[SEL],s=IDX[SEL],ring=s?['sector','field','fine domain'][s[4]]:'',h='<h2>'+esc(name(SEL))+'</h2><p><code>'+esc(SEL)+'</code>'+(ring?' · '+ring:'')+'</p>';
 var par=(LV&&LV.parents&&LV.parents[SEL])||(s&&s[5]?[s[5]]:[]);
 if(par.length)h+='<p>Parents: '+par.slice(0,4).map(function(p){return '<a href="#" data-go="'+esc(p)+'">'+esc(name(p))+'</a>'}).join(', ')+'</p>';
 h+='<h2>Levels</h2>';
 if(v){[['red','#f55',0],['green','#4d4',1],['blue','#58f',2]].forEach(function(c){h+='<p><span class="sw" style="background:'+c[1]+'"></span>'+c[0]+': <b>'+v[c[2]].toFixed(2)+'</b></p>'});
  h+='<p>saturation: '+v[3].toFixed(2)+(v[4]?' · claimed potential (grain): '+v[4].toFixed(2):'')+'</p>'}else h+='<p>No evidence here.</p>';
 var rows=KIND==='single'&&LV&&LV.rows&&LV.rows[SEL];
 if(rows&&rows.length){h+='<h2>Evidence ('+rows.length+')</h2>';rows.slice(0,12).forEach(function(r){h+='<div class="row"><b>'+esc(r.t)+'</b><br>'+esc(r.k)+' · '+esc(r.d)+' · '+esc(r.c)+(r.b?' · carried up':'')+'</div>'})}
 info.innerHTML=h;info.querySelectorAll('[data-go]').forEach(function(a){a.addEventListener('click',function(e){e.preventDefault();flyTo(a.getAttribute('data-go'),true)})})}
// ---- search and fly-to
function flyTo(id,andSelect){var c=sector(id);if(!c)return;var s=c.s,ppuNeed=Math.max(300/Math.max((s[3]-s[2]),(s[2]+s[3])/2*rad(s[1])),22/((s[2]+s[3])/2*rad(s[1])));
 var target=Math.min(wmax(),Math.max(cam.wpx*(andSelect?1:1),ppuNeed*2*EXT)),from={w:cam.wpx,x:cam.cx,y:cam.cy},t0=performance.now(),dur=450;anim=true;tv.idle=false;
 function step(t){var u=Math.min(1,(t-t0)/dur),e=u<.5?2*u*u:1-Math.pow(-2*u+2,2)/2;
  cam.wpx=Math.exp(Math.log(from.w)+(Math.log(target)-Math.log(from.w))*e);cam.cx=from.x+(c.wx-from.x)*e;cam.cy=from.y+(c.wy-from.y)*e;
  if(u<1)requestAnimationFrame(step);else{anim=false;if(andSelect)select(id);schedule()}draw()}
 requestAnimationFrame(step)}
function matches(q){q=q.trim().toLowerCase();if(!q)return[];var out=[];
 for(var id in IDX){var lab=((LV&&LV.labels&&LV.labels[id])||'').toLowerCase(),i=id.toLowerCase(),sc=-1;
  if(i===q||lab===q)sc=0;else if(lab.indexOf(q)===0||i.indexOf(q)===0)sc=1;else if(lab.indexOf(q)>=0||i.indexOf(q)>=0)sc=2;
  if(sc>=0)out.push([sc,lab||i,id])}
 out.sort(function(a,b){return a[0]-b[0]||(a[1]<b[1]?-1:a[1]>b[1]?1:0)});return out.slice(0,8).map(function(x){return x[2]})}
// ---- hit test
function hit(px,py){if(!VEC||!pm)return null;var z=tileZ(),k=TILE*Math.pow(2,z)/cam.wpx,o=origin(),wx=(o[0]+px)*k,wy=(o[1]+py)*k,x=Math.floor(wx/TILE),y=Math.floor(wy/TILE),T0=tiles.get(z+'/'+x+'/'+y);
 if(!T0||!T0.data)return null;var qx=(wx/TILE-x)*4096,qy=(wy/TILE-y)*4096,order=['fine','field','aggregate','sector'];
 for(var l=0;l<order.length;l++){var fs=T0.data[order[l]]||[];for(var i=0;i<fs.length;i++){var f=fs[i];
  for(var r=0;r<f.rings.length;r++){var g=f.rings[r],ins=false,n=g.length/2;for(var a=0,b=n-1;a<n;b=a++){var x1=g[2*a],y1=g[2*a+1],x2=g[2*b],y2=g[2*b+1];
   if((y1>qy)!==(y2>qy)&&qx<(x2-x1)*(qy-y1)/(y2-y1)+x1)ins=!ins}
   if(ins)return order[l]==='aggregate'?{id:members(f)._m[0],agg:f._m.length}:{id:f.tags.id,agg:0}}}}
 return null}
// ---- interaction
function zoomAt(px,py,f){var o=origin(),wx=(o[0]+px)/cam.wpx,wy=(o[1]+py)/cam.wpx;cam.wpx*=f;clampCam();cam.cx=wx-(px-W/2)/cam.wpx;cam.cy=wy-(py-H/2)/cam.wpx;clampCam();tv.idle=false;schedule()}
function resize(){var r=cv.getBoundingClientRect();DPR=window.devicePixelRatio||1;W=r.width;H=r.height;cv.width=Math.round(W*DPR);cv.height=Math.round(H*DPR);schedule()}
var drag=null,ptrs={};
cv.addEventListener('pointerdown',function(e){cv.setPointerCapture(e.pointerId);ptrs[e.pointerId]=[e.offsetX,e.offsetY];drag={x:e.offsetX,y:e.offsetY,moved:false,cx:cam.cx,cy:cam.cy,d:null};cv.style.cursor='grabbing'});
cv.addEventListener('pointermove',function(e){var n=Object.keys(ptrs).length;
 if(n>=2){ptrs[e.pointerId]=[e.offsetX,e.offsetY];var p=Object.values(ptrs),d=Math.hypot(p[0][0]-p[1][0],p[0][1]-p[1][1]);if(drag&&drag.d){zoomAt((p[0][0]+p[1][0])/2,(p[0][1]+p[1][1])/2,d/drag.d)}if(drag)drag.d=d;drag&&(drag.moved=true);return}
 if(drag&&ptrs[e.pointerId]){var dx=e.offsetX-drag.x,dy=e.offsetY-drag.y;if(Math.abs(dx)+Math.abs(dy)>3)drag.moved=true;
  if(drag.moved){cam.cx=drag.cx-dx/cam.wpx;cam.cy=drag.cy-dy/cam.wpx;clampCam();tv.idle=false;schedule()}return}
 var h=hit(e.offsetX,e.offsetY),id=h&&!h.agg?h.id:null;cv.title=h?(h.agg?h.agg+' small domains here: zoom in to tell them apart':name(h.id)):'';if(id!==HOV){HOV=id;tv.hover=id;schedule()}});
cv.addEventListener('pointerup',function(e){delete ptrs[e.pointerId];cv.style.cursor='grab';
 if(drag&&!drag.moved&&VEC){var h=hit(e.offsetX,e.offsetY);if(h&&h.agg)flyTo(h.id,true);else if(h)select(h.id);else{SEL=null;tv.selected=null;panel();schedule();scheduleHash()}}
 if(!Object.keys(ptrs).length)drag=null});
cv.addEventListener('pointerleave',function(){if(HOV){HOV=null;tv.hover=null;schedule()}});
cv.addEventListener('wheel',function(e){e.preventDefault();zoomAt(e.offsetX,e.offsetY,Math.exp(-e.deltaY*(e.deltaMode?.05:.0015)))},{passive:false});
cv.addEventListener('dblclick',function(e){zoomAt(e.offsetX,e.offsetY,2)});
window.addEventListener('keydown',function(e){if(e.target&&e.target.tagName==='INPUT')return;
 if(e.key==='+'||e.key==='=')zoomAt(W/2,H/2,1.5);else if(e.key==='-')zoomAt(W/2,H/2,1/1.5);else if(e.key==='0'){cam.wpx=fitW();cam.cx=cam.cy=.5;schedule()}
 else if(e.key==='Escape'){SEL=null;tv.selected=null;panel();schedule();scheduleHash()}
 else if(e.key.indexOf('Arrow')===0){var d=60/cam.wpx;if(e.key==='ArrowLeft')cam.cx-=d;if(e.key==='ArrowRight')cam.cx+=d;if(e.key==='ArrowUp')cam.cy-=d;if(e.key==='ArrowDown')cam.cy+=d;clampCam();schedule()}});
window.addEventListener('resize',resize);
// ---- levels sets: single, group (re-saturated sum), compare (overlap and differences)
function lum(l,k){return -k*Math.log(1-Math.min(l,1-1e-12))}
function groupIds(mask){var k=LS[0].tone_k,acc={};
 LS.forEach(function(lf,j){if(!mask[j])return;for(var d in lf.ids){var v=lf.ids[d],a=acc[d]||(acc[d]=[0,0,0,0,0,0]),s=[lum(v[0],k),lum(v[1],k),lum(v[2],k),lum(v[4],k)],m=s[0]+s[1]+s[2];
  for(var q=0;q<4;q++)a[q]+=s[q];a[4]+=m*v[3];a[5]+=m}});
 var out={};for(var d in acc){var a=acc[d],t=function(x){return 1-Math.exp(-x/k)};out[d]=[t(a[0]),t(a[1]),t(a[2]),a[5]>0?a[4]/a[5]:1,t(a[3])]}return out}
function compareIds(){var A=LS[0].ids,B=LS[1].ids,o={a:A,b:B,overlap:{},a_only:{},b_only:{}},ds={};for(var d in A)ds[d]=1;for(var d in B)ds[d]=1;
 for(var d in ds){var x=A[d],y=B[d],u=x||[0,0,0,1,0],w=y||[0,0,0,1,0],sat=x&&y?Math.min(u[3],w[3]):x?u[3]:w[3],ov=[],ao=[],bo=[];
  for(var j=0;j<3;j++){ov.push(Math.min(u[j],w[j]));ao.push(Math.max(u[j]-w[j],0));bo.push(Math.max(w[j]-u[j],0))}
  [['overlap',ov,sat],['a_only',ao,u[3]],['b_only',bo,w[3]]].forEach(function(t){if(t[1][0]||t[1][1]||t[1][2])o[t[0]][d]=t[1].concat([t[2],0])})}
 return o}
var MODES=['a','b','overlap','a_only','b_only'];
function applyIds(){if(KIND==='group')IDS=groupIds(MEM);else if(KIND==='compare')IDS=SETS[MODES[MODE]];else IDS=LS[0].ids;tv.idle=false;panel();schedule()}
async function bootLevels(){var sets=CFG.levelsets||(CFG.levels?[CFG.levels]:null);
 if(!sets&&CFG.urls){var us=CFG.urls.levelsets||[CFG.urls.levels];sets=[];for(var i=0;i<us.length;i++)sets.push(await (await fetch(us[i])).json())}
 LS=sets;LV=LS[0];KIND=CFG.kind||'single';MEM=LS.map(function(){return true});if(KIND==='compare')SETS=compareIds();applyIds();buildSets()}
function buildSets(){var el=document.getElementById('sets');if(!el||KIND==='single')return;
 if(KIND==='group')LS.forEach(function(lf,j){var l=document.createElement('label');l.className='ch';var c=document.createElement('input');c.type='checkbox';c.checked=true;
  c.addEventListener('change',function(){MEM[j]=c.checked;applyIds()});l.appendChild(c);l.appendChild(document.createTextNode(' '+(lf.title||('image '+(j+1)))));el.appendChild(l)});
 else{var nm=function(j){return LS[j].title||('image '+(j+1))},lab=[nm(0),nm(1),'overlap','only '+nm(0),'only '+nm(1)];
  lab.forEach(function(t,j){var l=document.createElement('label');l.className='ch';var c=document.createElement('input');c.type='radio';c.name='mode';c.checked=j===0;
   c.addEventListener('change',function(){MODE=j;applyIds()});l.appendChild(c);l.appendChild(document.createTextNode(' '+t));el.appendChild(l)})}}
tv.setMode=function(j){MODE=j;applyIds()};tv.setMembers=function(m){MEM=m.slice();applyIds()};
// ---- page wiring
var sb=document.getElementById('search'),rl=document.getElementById('results');
if(sb){var show=function(){var m=matches(sb.value);rl.innerHTML='';m.forEach(function(id,i){var li=document.createElement('li');li.textContent=name(id)+'  ('+id+')';
  if(i===0)li.className='on';li.addEventListener('click',function(){go(id)});rl.appendChild(li)});rl.style.display=m.length?'block':'none'};
 var go=function(id){rl.style.display='none';sb.value=name(id);flyTo(id,true)};
 sb.addEventListener('input',show);sb.addEventListener('keydown',function(e){if(e.key==='Enter'){var m=matches(sb.value);if(m.length)go(m[0])}else if(e.key==='Escape'){rl.style.display='none'}})}
['r','g','b'].forEach(function(k){var el=document.getElementById('ch-'+({r:'red',g:'green',b:'blue'})[k]);if(el)el.addEventListener('change',function(){ch[k]=el.checked;tv.idle=false;schedule();scheduleHash()})});
tv.view=function(){return {zoom:zoomOf(),cx:cam.cx,cy:cam.cy,selected:tv.selected}};
tv.size=function(){var r=cv.getBoundingClientRect();return {w:r.right,h:r.bottom}};
tv.screenOf=screenOf;
tv.setView=function(z,ox,oy){cam.wpx=TILE*Math.pow(2,z);cam.cx=(ox+W/2)/cam.wpx;cam.cy=(oy+H/2)/cam.wpx;tv.idle=false;schedule()};
tv.lookAt=function(id,z){var c=sector(id);if(!c)return;cam.wpx=TILE*Math.pow(2,z);clampCam();cam.cx=c.wx;cam.cy=c.wy;tv.idle=false;schedule()};
tv.levelsOf=function(id){return IDS[id]||null};
tv.clearLog=function(){tv.tilesFetched=[];tv.tileBytes=0};
tv.pixelAt=function(x,y){var r=cv.getBoundingClientRect(),d=ctx.getImageData(Math.round((x-r.left)*DPR),Math.round((y-r.top)*DPR),1,1).data;return [d[0],d[1],d[2]]};
tv.litPixels=function(){var d=ctx.getImageData(0,0,cv.width,cv.height).data,n=0;for(var i=0;i<d.length;i+=4)if(d[i]+d[i+1]+d[i+2]>45)n++;return n};
(async function(){try{
 resize();await bootSource();
 if(VEC){if(CFG.source!=='offline'&&!META.index){META=await pm.metadata();IDX=META.index||{}}await bootLevels()}
 var has=readHash();if(!has){cam.wpx=fitW();cam.cx=cam.cy=.5}
 ['r','g','b'].forEach(function(k){var el=document.getElementById('ch-'+({r:'red',g:'green',b:'blue'})[k]);if(el)el.checked=ch[k]});
 if(SEL)tv.selected=SEL;panel();clampCam();
 tv.ready=true;schedule();
 var chk=setInterval(function(){if(!pending&&!anim&&!drawQ){tv.idle=true}},120);
}catch(e){tv.errors.push(String(e));tv.ready=true;tv.idle=true}})();
})();
"""


def _page(cfg, title, blob=None, vector=True):
    t = escape(title)
    toolbar = ('<input id="search" type="search" placeholder="Search a domain by name or id" aria-label="Search" autocomplete="off">'
               '<ul id="results" style="display:none"></ul>'
               '<span><label class="ch"><input type="checkbox" id="ch-red" checked> red</label>'
               '<label class="ch"><input type="checkbox" id="ch-green" checked> green</label>'
               '<label class="ch"><input type="checkbox" id="ch-blue" checked> blue</label></span>') if vector else ""
    note = ("Map of the basemap: drag to pan, wheel or pinch to zoom, click a slice to select. Everything is in this page."
            if vector and cfg["source"] == "offline" else
            "Map of the basemap: drag to pan, wheel or pinch to zoom, click a slice to select." if vector else
            "Raster, 1x to 4x. Deeper views are the vector version's job.")
    blob_tag = f'<script id="blob" type="text/plain">{blob}</script>' if blob is not None else ""
    cfg_json = json.dumps(cfg, sort_keys=True, separators=(",", ":")).replace("<", "\\u003c")
    return (f'<!doctype html>\n<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
            f'<title>{t}</title><style>{CSS}</style></head><body>'
            f'<header><h1>{t}</h1>{toolbar}<span id="sets"></span><p class="note">{escape(note)} Basemap {escape(str(cfg["meta"]["basemap"]))}.</p></header>'
            f'<div id="wrap"><div id="stage"><canvas id="c" aria-label="Life image map"></canvas><div id="pos"></div></div>'
            f'<aside><div id="info"></div>{LEGEND}</aside></div>'
            f'<noscript><p>This viewer needs JavaScript.</p></noscript>'
            f'<script id="cfg" type="application/json">{cfg_json}</script>{blob_tag}<script>{JS}</script></body></html>\n')


def _meta(archive_bytes):
    return T.PMTiles(archive_bytes).metadata


def _sets(lf, kind):
    if kind not in ("single", "group", "compare"):
        raise ValueError(f"kind must be single, group or compare, not {kind!r}")
    lfs = list(lf) if isinstance(lf, (list, tuple)) else [lf]
    if kind == "compare" and len(lfs) != 2:
        raise ValueError("a comparison needs exactly two levels files")
    if kind != "single" and len(lfs) < 2:
        raise ValueError(f"a {kind} view needs at least two levels files")
    if len({x["basemap"] for x in lfs}) > 1:
        raise ValueError("levels files are on different basemap versions; migrate them first (tiles.migrate_levels)")
    return lfs


def offline_vector_html(archive_bytes, lf, title, kind="single"):
    """One self-contained page: the whole pyramid (PMTiles, base64) and the levels file(s) embedded; no network. `kind` single
    (one levels file), group (the re-saturated sum of several, members switchable) or compare (two: each, the overlap and
    each side's difference), the set operations of `interactive.py`."""
    meta = _meta(archive_bytes)
    cfg = {"mode": "vector", "source": "offline", "meta": meta, "levelsets": _sets(lf, kind), "kind": kind}
    return _page(cfg, title, base64.b64encode(archive_bytes).decode())


def online_vector_dir(out, archive_bytes, lf, title, kind="single"):
    """A static folder: index.html, basemap.pmtiles (fetched by range) and levels.json (fetched once)."""
    from pathlib import Path
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    meta = _meta(archive_bytes)
    (out / "basemap.pmtiles").write_bytes(archive_bytes)
    lfs = _sets(lf, kind)
    names = []
    for j, x in enumerate(lfs):
        names.append("levels.json" if len(lfs) == 1 else f"levels-{j}.json")
        (out / names[-1]).write_text(json.dumps(x, sort_keys=True, separators=(",", ":")), encoding="utf-8")
    cfg = {"mode": "vector", "source": "online", "meta": {k: v for k, v in meta.items() if k != "index"} | {"index": meta["index"]},
           "urls": {"tiles": "basemap.pmtiles", "levels": names[0], "levelsets": names}, "kind": kind}
    (out / "index.html").write_text(_page(cfg, title), encoding="utf-8")
    return out


def offline_raster_html(pngs, meta, lf, title):
    """One self-contained page: the PNG pyramid (zoom 0 to 2) embedded as base64; no network."""
    blob = json.dumps({f"{z}/{x}/{y}": base64.b64encode(b).decode() for (z, x, y), b in sorted(pngs.items())}, separators=(",", ":"))
    cfg = {"mode": "raster", "source": "offline", "meta": {k: v for k, v in meta.items() if k != "index"}}
    return _page(cfg, title, blob, vector=False)


def online_raster_dir(out, pngs, meta, title):
    """A static folder: index.html and tiles/z/x/y.png (zoom 0 to 2)."""
    from pathlib import Path
    out = Path(out)
    for (z, x, y), b in pngs.items():
        p = out / "tiles" / str(z) / str(x) / f"{y}.png"
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(b)
    cfg = {"mode": "raster", "source": "online", "meta": {k: v for k, v in meta.items() if k != "index"}, "urls": {"tiles": "tiles/"}}
    (out / "index.html").write_text(_page(cfg, title, vector=False), encoding="utf-8")
    return out
