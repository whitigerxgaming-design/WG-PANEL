(function(){
  function login(){
    var onLogin=/^\/auth\/login/.test(location.pathname);
    document.body&&document.body.classList.toggle('wg-login',onLogin);
    if(!onLogin)return;
    var f=document.querySelector('form');
    if(!f||document.querySelector('.wg-tiger'))return;
    var img=document.createElement('img');img.src='/wg/tiger.jpg';img.className='wg-tiger';img.alt='WG PANEL';
    document.body.appendChild(img);
    var b=document.createElement('div');b.className='wg-brand';b.textContent='WG PANEL';document.body.appendChild(b);
    var a=document.createElement('a');a.href='/auth/register';a.className='wg-register';a.textContent='Create a new account';
    f.appendChild(a);
  }
  function admin(){
    var m=document.querySelector('.sidebar-menu');
    if(!m||document.querySelector('#wg-theme-link'))return;
    var li=document.createElement('li');li.id='wg-theme-link';
    li.innerHTML='<a href="/admin/wg-theme"><i class="fa fa-paint-brush"></i> <span>WG Theme</span></a>';
    m.appendChild(li);
  }
  function run(){login();admin();}
  new MutationObserver(run).observe(document.documentElement,{childList:true,subtree:true});
  document.addEventListener('DOMContentLoaded',run);run();
})();
