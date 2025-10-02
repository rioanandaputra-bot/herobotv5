<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Channel extends Model
{
    use HasFactory;

    protected $fillable = [
        'team_id',
        'name',
        'type',
        'phone',
        'is_connected',
    ];

    protected $casts = [
        'is_connected' => 'boolean',
    ];

    public function team()
    {
        return $this->belongsTo(Team::class);
    }

    public function bots()
    {
        return $this->morphToMany(Bot::class, 'connectable', 'bot_connections');
    }

    public function chatHistories()
    {
        return $this->hasMany(ChatHistory::class);
    }
}
