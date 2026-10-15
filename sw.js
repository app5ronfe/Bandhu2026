// Bandhu2026: permite jogar mesmo com pouca rede. O jogo é sempre atualizado quando há internet.
const CACHE='bandhu-v31';
const ASSETS=['./','./index.html','./manifest.webmanifest','./icon-192.png','./icon-512.png','./apple-touch-icon.png','./menu.mp3'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(CACHE).then(c=>c.addAll(ASSETS)).then(()=>self.skipWaiting()));});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));});
self.addEventListener('fetch',e=>{
  const req=e.request,url=new URL(req.url);
  if(req.method!=='GET'||url.origin!==self.location.origin||req.headers.has('range')||url.pathname.endsWith('jogo.mp3'))return; // ranking (Supabase) e fontes vão sempre à rede
  if(req.mode==='navigate'||url.pathname.endsWith('/')||url.pathname.endsWith('index.html')){
    e.respondWith(fetch(req).then(r=>{const cp=r.clone();caches.open(CACHE).then(c=>c.put('./index.html',cp));return r;}).catch(()=>caches.match('./index.html')));return;}
  e.respondWith(caches.match(req).then(m=>m||fetch(req)));
});
