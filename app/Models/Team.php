<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Laravel\Jetstream\Events\TeamCreated;
use Laravel\Jetstream\Events\TeamDeleted;
use Laravel\Jetstream\Events\TeamUpdated;
use Laravel\Jetstream\Team as JetstreamTeam;

class Team extends JetstreamTeam
{
    use HasFactory;

    /**
     * The attributes that should be cast.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'personal_team' => 'boolean',
    ];

    /**
     * The attributes that are mass assignable.
     *
     * @var string<int, string>
     */
    protected $fillable = [
        'name',
        'personal_team',
    ];

    /**
     * The event map for the model.
     *
     * @var array<string, class-string>
     */
    protected $dispatchesEvents = [
        'created' => TeamCreated::class,
        'updated' => TeamUpdated::class,
        'deleted' => TeamDeleted::class,
    ];

    public function bots()
    {
        return $this->hasMany(Bot::class);
    }

    public function knowledges()
    {
        return $this->hasMany(Knowledge::class);
    }

    public function knowledgeVectors()
    {
        return $this->hasManyThrough(KnowledgeVector::class, Knowledge::class);
    }

    public function channels()
    {
        return $this->hasMany(Channel::class);
    }

    public function transactions()
    {
        return $this->hasMany(Transaction::class);
    }

    public function balance()
    {
        return $this->hasOne(Balance::class)->withDefault([
            'amount' => 0,
        ]);
    }

    public function tools()
    {
        return $this->hasMany(Tool::class);
    }

    public function purge()
    {
        $this->knowledgeVectors()->delete();

        $this->knowledges()->delete();

        $this->tools()->delete();

        $this->balance()->delete();

        $this->channels()->delete();

        $this->bots()->delete();

        parent::purge();
    }
}
