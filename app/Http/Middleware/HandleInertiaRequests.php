<?php

namespace App\Http\Middleware;

use Illuminate\Http\Request;
use Inertia\Middleware;

class HandleInertiaRequests extends Middleware
{
    /**
     * The root template that's loaded on the first page visit.
     *
     * @see https://inertiajs.com/server-side-setup#root-template
     *
     * @var string
     */
    protected $rootView = 'app';

    /**
     * Determines the current asset version.
     *
     * @see https://inertiajs.com/asset-versioning
     */
    public function version(Request $request): ?string
    {
        return parent::version($request);
    }

    /**
     * Defines the props that are shared by default.
     *
     * @see https://inertiajs.com/shared-data
     */
    public function share(Request $request): array
    {
        $session = collect($request->session()->all())
            ->reject(fn ($value, $key) => 
                str_starts_with($key, 'login_web_') ||
                str_starts_with($key, 'password_hash_') ||
                str_starts_with($key, '_')
            );

        return array_merge(parent::share($request), [
            'flash' => $session->all(),
            'appEdition' => config('app.edition'),
        ]);
    }
}
