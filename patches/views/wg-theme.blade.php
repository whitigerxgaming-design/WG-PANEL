@extends('layouts.admin')
@section('title') WG Theme @endsection
@section('content-header')
  <h1>WG Theme<small>Only admins can change colours.</small></h1>
@endsection
@section('content')
<div class="row"><div class="col-md-6"><div class="box box-primary">
  <form method="POST" action="/admin/wg-theme">
    {!! csrf_field() !!}
    <div class="box-body">
      @if(session('success'))<div class="alert alert-success">{{ session('success') }}</div>@endif
      @foreach(['accent' => 'Accent colour', 'bg' => 'Background', 'panel' => 'Panels / header', 'text' => 'Text'] as $k => $label)
        <div class="form-group"><label>{{ $label }}</label>
        <input type="color" name="{{ $k }}" value="{{ $c[$k] }}" class="form-control" style="height:40px"></div>
      @endforeach
    </div>
    <div class="box-footer"><button class="btn btn-primary">Save theme</button></div>
  </form>
</div></div></div>
@endsection
