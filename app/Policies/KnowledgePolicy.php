<?php

namespace App\Policies;

use App\Models\Knowledge;
use App\Models\User;
use Illuminate\Auth\Access\HandlesAuthorization;

class KnowledgePolicy
{
    use HandlesAuthorization;

    /**
     * Determine whether the user can view any models.
     *
     * @return \Illuminate\Auth\Access\Response|bool
     */
    public function viewAny(User $user)
    {
        return true;
    }

    /**
     * Determine whether the user can view the model.
     *
     * @return \Illuminate\Auth\Access\Response|bool
     */
    public function view(User $user, Knowledge $knowledge)
    {
        return $user->currentTeam->id === $knowledge->team_id;
    }

    /**
     * Determine whether the user can create models.
     *
     * @return \Illuminate\Auth\Access\Response|bool
     */
    public function create(User $user)
    {
        return true;
    }

    /**
     * Determine whether the user can update the model.
     *
     * @return \Illuminate\Auth\Access\Response|bool
     */
    public function update(User $user, Knowledge $knowledge)
    {
        return $user->currentTeam->id === $knowledge->team_id;
    }

    /**
     * Determine whether the user can delete the model.
     *
     * @return \Illuminate\Auth\Access\Response|bool
     */
    public function delete(User $user, Knowledge $knowledge)
    {
        return $user->currentTeam->id === $knowledge->team_id;
    }

    /**
     * Determine whether the user can restore the model.
     *
     * @return \Illuminate\Auth\Access\Response|bool
     */
    public function restore(User $user, Knowledge $knowledge)
    {
        return $user->currentTeam->id === $knowledge->team_id;
    }

    /**
     * Determine whether the user can permanently delete the model.
     *
     * @return \Illuminate\Auth\Access\Response|bool
     */
    public function forceDelete(User $user, Knowledge $knowledge)
    {
        return $user->currentTeam->id === $knowledge->team_id;
    }
}
