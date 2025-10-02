<?php

namespace App\Http\Controllers;

use App\Models\Balance;
use App\Models\Transaction;
use App\Services\XenditService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Inertia\Inertia;

class BillingController extends Controller
{
    protected $xenditService;

    public function __construct(XenditService $xenditService)
    {
        $this->xenditService = $xenditService;

        if (config('app.edition') !== 'cloud') {
            abort(404);
        }
    }

    public function index(Request $request)
    {
        $team = $request->user()->currentTeam;
        $balance = $team->balance;
        $transactions = $team->transactions()
            ->latest()
            ->take(10)
            ->get()
            ->map(function ($transaction) {
                $currentStatus = $this->determineStatus($transaction);

                return [
                    'id' => $transaction->id,
                    'created_at' => $transaction->created_at,
                    'updated_at' => $transaction->updated_at,
                    'amount' => $transaction->amount,
                    'type' => $transaction->type,
                    'transaction_type' => $transaction->transaction_type,
                    'description' => $transaction->description,
                    'status' => $currentStatus,
                    'payment_method' => $transaction->payment_method,
                    'payment_details' => $transaction->payment_details,
                    'expired_at' => $transaction->expired_at,
                    'formatted_status' => ucfirst($currentStatus),
                    'status_color' => $this->getStatusColor($currentStatus),
                    'formatted_type' => ucfirst(str_replace('_', ' ', $transaction->type)),
                    'type_color' => $this->getTypeColor($transaction->type),
                ];
            });

        return Inertia::render('Billing/Index', [
            'balance' => $balance,
            'transactions' => $transactions,
            'flash' => [
                'success' => session('success'),
                'error' => session('error'),
            ],
        ]);
    }

    private function getStatusColor($status)
    {
        return match ($status) {
            'completed' => 'green',
            'pending' => 'yellow',
            'failed' => 'red',
            'expired' => 'gray',
            default => 'gray'
        };
    }

    private function determineStatus($transaction)
    {
        if ($transaction->status === 'pending' &&
            $transaction->expired_at &&
            now()->isAfter($transaction->expired_at)) {
            return 'expired';
        }

        return $transaction->status;
    }

    private function getTypeColor($type)
    {
        return match ($type) {
            'topup' => 'green',
            'usage' => 'blue',
            'refund' => 'yellow',
            default => 'gray'
        };
    }

    public function topup(Request $request)
    {
        $request->validate([
            'amount' => 'required|numeric|min:10000',
        ]);

        $team = $request->user()->currentTeam;
        $externalId = 'topup_'.$team->id.'_'.time();

        $transaction = Transaction::create([
            'team_id' => $team->id,
            'amount' => $request->amount,
            'type' => 'topup',
            'transaction_type' => 'credit',
            'description' => 'Credit top-up',
            'status' => 'pending',
            'external_id' => $externalId,
        ]);

        $params = [
            'external_id' => $externalId,
            'amount' => $request->amount,
            'payer_email' => $request->user()->email,
            'customer_name' => $request->user()->name,
            'description' => 'Top up credits for '.$team->name,
            'success_redirect_url' => route('billing.topup.success', ['transaction' => $transaction->id]),
            'failure_redirect_url' => route('billing.topup.failure', ['transaction' => $transaction->id]),
        ];

        try {
            $invoice = $this->xenditService->createInvoice($params);

            $transaction->update([
                'payment_id' => $invoice['id'],
                'payment_details' => $invoice,
                'expired_at' => isset($invoice['expiry_date']) ? $invoice['expiry_date'] : null,
            ]);

            return Inertia::location($invoice['invoice_url']);
        } catch (\Exception $e) {
            $transaction->update(['status' => 'failed']);
            Log::error('Xendit invoice creation failed', [
                'error' => $e->getMessage(),
                'transaction_id' => $transaction->id,
            ]);

            return redirect()->back()->with('error', 'Unable to process payment. Please try again.');
        }
    }

    public function topupSuccess(Request $request)
    {
        $transaction = Transaction::findOrFail($request->transaction);

        if ($transaction->status !== 'completed') {
            return redirect()->route('billing.index')
                ->with('error', 'Payment is still being processed. Please wait for confirmation.');
        }

        return redirect()->route('billing.index')
            ->with('success', 'Payment successful! Your credits have been added.');
    }

    public function topupFailure(Request $request)
    {
        $transaction = Transaction::findOrFail($request->transaction);

        if ($transaction->status === 'completed') {
            return redirect()->route('billing.index')
                ->with('success', 'Payment has been completed successfully.');
        }

        $transaction->update(['status' => 'failed']);

        return redirect()->route('billing.index')
            ->with('error', 'Payment failed. Please try again or contact support if the issue persists.');
    }

    public function handleWebhook(Request $request)
    {
        $callbackToken = $request->header('x-callback-token');
        if ($callbackToken === null || ! $this->xenditService->validateCallback($callbackToken)) {
            Log::warning('Invalid or missing Xendit webhook token');

            return response()->json(['error' => 'Invalid token', 'token' => $callbackToken], 401);
        }

        $payload = $request->all();
        Log::info('Xendit webhook received', $payload);

        // Handle direct invoice payment notification
        if (isset($payload['status'])) {
            try {
                DB::transaction(function () use ($payload) {
                    $transaction = Transaction::where('external_id', $payload['external_id'])
                        ->where('status', 'pending')
                        ->first();

                    if (! $transaction) {
                        Log::info('Transaction not found or not in pending status', [
                            'external_id' => $payload['external_id'],
                        ]);

                        return;
                    }

                    // Check if transaction is expired
                    if ($transaction->expired_at && now()->isAfter($transaction->expired_at)) {
                        $transaction->update(['status' => 'expired']);
                        Log::info('Transaction marked as expired', [
                            'transaction_id' => $transaction->id,
                        ]);

                        return;
                    }

                    if ($payload['status'] === 'PAID') {
                        $transaction->update([
                            'status' => 'completed',
                            'payment_method' => $payload['payment_method'],
                            'payment_details' => array_merge($transaction->payment_details ?? [], $payload),
                        ]);

                        $balance = Balance::firstOrCreate(
                            ['team_id' => $transaction->team_id],
                            ['amount' => 0]
                        );
                        // Amount is now stored as integer (multiplied by 1,000,000)
                        // The setAmountAttribute in Balance model will handle the conversion
                        $currentDecimalAmount = $balance->decimal_amount;
                        $balance->amount = $currentDecimalAmount + $payload['amount'];
                        $balance->save();

                        Log::info('Successfully processed Xendit payment', [
                            'transaction_id' => $transaction->id,
                            'amount' => $payload['amount'],
                        ]);
                    }
                });
            } catch (\Exception $e) {
                Log::error('Error processing Xendit webhook', [
                    'error' => $e->getMessage(),
                    'payload' => $payload,
                ]);

                return response()->json(['error' => 'Processing error'], 500);
            }

            return response()->json(['success' => true]);
        }

        return response()->json(['success' => true]);
    }
}
