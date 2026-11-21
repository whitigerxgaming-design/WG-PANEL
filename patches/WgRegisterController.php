<?php

namespace Pterodactyl\Http\Controllers\Auth;

use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Pterodactyl\Services\Users\UserCreationService;

class WgRegisterController extends Controller
{
    public function __construct(private UserCreationService $creation)
    {
    }

    public function show()
    {
        return view('wg.register');
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'username' => 'required|alpha_dash|min:3|max:191|unique:users,username',
            'email' => 'required|email|max:191|unique:users,email',
            'name_first' => 'required|string|max:191',
            'name_last' => 'required|string|max:191',
            'password' => 'required|string|min:8|confirmed',
        ]);

        $this->creation->handle($data);

        return redirect('/auth/login');
    }
}
