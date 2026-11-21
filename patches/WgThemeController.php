<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class WgThemeController extends Controller
{
    private function defaults(): array
    {
        return ['accent' => '#38bdf8', 'bg' => '#0b1020', 'panel' => '#121a2f', 'text' => '#e6edf7'];
    }

    public function show()
    {
        $saved = json_decode(@file_get_contents(public_path('wg/colors.json')) ?: '{}', true) ?: [];

        return view('admin.wg-theme', ['c' => array_merge($this->defaults(), $saved)]);
    }

    public function save(Request $request)
    {
        $rule = ['required', 'regex:/^#[0-9a-fA-F]{6}$/'];
        $c = $request->validate(['accent' => $rule, 'bg' => $rule, 'panel' => $rule, 'text' => $rule]);

        file_put_contents(public_path('wg/colors.json'), json_encode($c));
        file_put_contents(
            public_path('wg/colors.css'),
            ":root{--wg-accent:{$c['accent']};--wg-bg:{$c['bg']};--wg-panel:{$c['panel']};--wg-text:{$c['text']}}"
        );

        return back()->with('success', 'Theme saved.');
    }
}
