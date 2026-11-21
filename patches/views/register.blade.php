<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Register - {{ config('app.name') }}</title>
<link rel="stylesheet" href="/wg/wg.css"><link rel="stylesheet" href="/wg/colors.css">
<style>
body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;font-family:system-ui,sans-serif}
.card{position:relative;z-index:2;width:min(420px,92vw);background:var(--wg-panel);padding:32px;border-radius:14px;box-shadow:0 20px 60px #0008}
h1{margin:0 0 20px;font-size:22px;letter-spacing:.15em}
label{display:block;font-size:13px;margin:14px 0 6px;opacity:.85}
input{width:100%;box-sizing:border-box;padding:11px 12px;border-radius:8px;border:1px solid #2b3858;background:var(--wg-bg);color:var(--wg-text)}
button{width:100%;margin-top:22px;padding:12px;border:0;cursor:pointer;font-size:15px}
.err{background:#7f1d1d;padding:10px;border-radius:8px;margin-bottom:10px;font-size:13px}
.row{display:flex;gap:10px}
</style></head>
<body class="wg-login"><img class="wg-tiger" src="/wg/tiger.jpg" alt="">
<form class="card" method="POST" action="/auth/register">
  {!! csrf_field() !!}
  <h1>WG PANEL</h1>
  @if($errors->any())<div class="err">@foreach($errors->all() as $e){{ $e }}<br>@endforeach</div>@endif
  <div class="row"><div><label>First name</label><input name="name_first" value="{{ old('name_first') }}" required></div>
  <div><label>Last name</label><input name="name_last" value="{{ old('name_last') }}" required></div></div>
  <label>Username</label><input name="username" value="{{ old('username') }}" required>
  <label>Email</label><input type="email" name="email" value="{{ old('email') }}" required>
  <label>Password (min 8)</label><input type="password" name="password" required>
  <label>Confirm password</label><input type="password" name="password_confirmation" required>
  <button type="submit">Create account</button>
  <a class="wg-register" href="/auth/login">Already have an account? Log in</a>
</form></body></html>
