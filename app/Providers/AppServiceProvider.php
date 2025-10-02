<?php

namespace App\Providers;

use App\Services\TelegramService;
use App\Services\ToolService;
use App\Services\WhatsApp\WhatsAppService;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\ServiceProvider;
use InvalidArgumentException;
use Inertia\Inertia;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     *
     * @return void
     */
    public function register()
    {
        $this->app->singleton('whatsapp', function ($app) {
            return new WhatsAppService(config('services.whatsapp.base_url'));
        });

        $this->app->singleton(TelegramService::class, function ($app) {
            return new TelegramService;
        });

        $this->app->singleton(ToolService::class, function ($app) {
            return new ToolService();
        });
    }

    /**
     * Bootstrap any application services.
     *
     * @return void
     */
    public function boot()
    {
        if (config('app.force_https')) {
            URL::forceScheme('https');
        }

        Inertia::share([
            'environment' => fn () => app()->environment(),
        ]);
        
        // Validate AI service configuration
        $this->validateAIConfiguration();
    }

    private function validateAIConfiguration()
    {
        $chatService = config('services.ai.chat_service');
        $embeddingService = config('services.ai.embedding_service');
        $speechToTextService = config('services.ai.speech_to_text_service');

        // Validate chat service
        if (!in_array($chatService, ['openrouter', 'openai', 'gemini'])) {
            throw new InvalidArgumentException("Invalid chat service configured: {$chatService}");
        }

        // Validate embedding service
        if (!in_array($embeddingService, ['openai', 'gemini'])) {
            throw new InvalidArgumentException("Invalid embedding service configured: {$embeddingService}");
        }

        // Validate speech-to-text service
        if (!in_array($speechToTextService, ['openai', 'gemini'])) {
            throw new InvalidArgumentException("Invalid speech-to-text service configured: {$speechToTextService}");
        }

        // Check API keys
        $chatApiKey = match($chatService) {
            'openrouter' => config('services.openrouter.api_key'),
            'openai' => config('services.openai.api_key'),
            'gemini' => config('services.gemini.api_key'),
        };

        $embeddingApiKey = match($embeddingService) {
            'openai' => config('services.openai.api_key'),
            'gemini' => config('services.gemini.api_key'),
        };

        $speechToTextApiKey = match($speechToTextService) {
            'openai' => config('services.openai.api_key'),
            'gemini' => config('services.gemini.api_key'),
        };

        if (empty($chatApiKey)) {
            Log::warning("Chat service '{$chatService}' configured but API key is missing");
        }

        if (empty($embeddingApiKey)) {
            Log::warning("Embedding service '{$embeddingService}' configured but API key is missing");
        }

        if (empty($speechToTextApiKey)) {
            Log::warning("Speech-to-text service '{$speechToTextService}' configured but API key is missing");
        }
    }
}
