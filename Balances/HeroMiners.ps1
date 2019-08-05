﻿param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{coin = "Arqma";         symbol = "ARQ";   algo = "CnTurtle";    port = 10320; fee = 0.9; rpc = "arqma"}
    [PSCustomObject]@{coin = "Arqma+Iridium"; symbol = "ARQ";   algo = "CnTurtle";    port = 10630; fee = 0.9; rpc = "iridium"; symbol2 = "IRD"}
    [PSCustomObject]@{coin = "Arqma+Plenteum";symbol = "ARQ";   algo = "CnTurtle";    port = 10630; fee = 0.9; rpc = "arqple"; symbol2 = "PLE"}
    [PSCustomObject]@{coin = "Arqma+Turtle";  symbol = "ARQ";   algo = "CnTurtle";    port = 10320; fee = 0.9; rpc = "arqma"; symbol2 = "TRTL"}
    [PSCustomObject]@{coin = "Arqma+CyprusCoin";symbol = "ARQ"; algo = "CnTurtle";    port = 10670; fee = 0.9; rpc = "cypruscoin"; symbol2 = "XCY"}
    [PSCustomObject]@{coin = "BitTube";       symbol = "TUBE";  algo = "CnSaber";     port = 10280; fee = 0.9; rpc = "tube"}
    [PSCustomObject]@{coin = "Conceal";       symbol = "CCX";   algo = "CnConceal";   port = 10361; fee = 0.9; rpc = "conceal"}
    [PSCustomObject]@{coin = "Graft";         symbol = "GRFT";  algo = "CnRwz";       port = 10100; fee = 0.9; rpc = "graft"}
    [PSCustomObject]@{coin = "Haven";         symbol = "XHV";   algo = "CnHaven";     port = 10140; fee = 0.9; rpc = "haven"}
    [PSCustomObject]@{coin = "Haven+Bloc";    symbol = "XHV";   algo = "CnHaven";     port = 10450; fee = 0.9; rpc = "havenbloc";  symbol2 = "BLOC"}
    [PSCustomObject]@{coin = "Loki";          symbol = "LOKI";  algo = "RxLoki";      port = 10111; fee = 0.9; rpc = "loki"}
    [PSCustomObject]@{coin = "Masari";        symbol = "MSR";   algo = "CnHalf";      port = 10150; fee = 0.9; rpc = "masari"}
    [PSCustomObject]@{coin = "Monero";        symbol = "XMR";   algo = "CnR";         port = 10190; fee = 0.9; rpc = "monero"}
    [PSCustomObject]@{coin = "Qrl";           symbol = "QRL";   algo = "CnV7";        port = 10370; fee = 0.9; rpc = "qrl"}
    [PSCustomObject]@{coin = "Ryo";           symbol = "RYO";   algo = "CnGpu";       port = 10270; fee = 0.9; rpc = "ryo"}
    [PSCustomObject]@{coin = "Scala";         symbol = "XLA";   algo = "CnHalf";      port = 10130; fee = 0.9; rpc = "scala"}
    [PSCustomObject]@{coin = "Scala";         symbol = "XTC";   algo = "CnHalf";      port = 10130; fee = 0.9; rpc = "scala"}
    [PSCustomObject]@{coin = "Sumocoin";      symbol = "SUMO";  algo = "CnGpu";       port = 10610; fee = 0.9; rpc = "sumo"}
    [PSCustomObject]@{coin = "Swap";          symbol = "XWP";   algo = "Cuckaroo29s"; port = 10441; fee = 0.9; rpc = "swap"; divisor = 32}
    [PSCustomObject]@{coin = "Triton";        symbol = "XTRI";  algo = "CnLiteV7";    port = 10600; fee = 0.9; rpc = "triton"}
    [PSCustomObject]@{coin = "Triton+NibbleClassic";symbol = "XTRI";algo = "CnTurtle";port = 10600; fee = 0.9; rpc = "triton"; symbol2 = "NBX"}
    [PSCustomObject]@{coin = "Turtle";        symbol = "TRTL";  algo = "CnTurtle";    port = 10380; fee = 0.9; rpc = "turtlecoin"}
    [PSCustomObject]@{coin = "uPlexa";        symbol = "UPX";   algo = "CnUpx";       port = 10470; fee = 0.9; rpc = "uplexa"}
    [PSCustomObject]@{coin = "WowNero";       symbol = "WOW";   algo = "RxWow";       port = 10660; fee = 0.9; rpc = "wownero"}
    [PSCustomObject]@{coin = "Xcash";         symbol = "XCASH"; algo = "CnHeavyX";    port = 10440; fee = 0.9; rpc = "xcash"}
)

$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)" -and (-not $_.symbol2 -or $Config.Pools.$Name.Wallets."$($_.symbol2)")} | Foreach-Object {
    $Pool_Currency = $_.symbol
    $Pool_Currency2 = $_.symbol2
    $Pool_RpcPath  = $_.rpc.ToLower()

    $Pool_Request = [PSCustomObject]@{}
    $Request = [PSCustomObject]@{}

    try {
        $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).herominers.com/api/stats" -tag $Name -cycletime 120
        $Divisor = $Pool_Request.config.coinUnits

        $Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).herominers.com/api/stats_address?address=$(Get-UrlEncode (Get-WalletWithPaymentId $Config.Pools.$Name.Wallets.$Pool_Currency -replace "^solo:"))" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60) -timeout 15
        if (-not $Request.stats -or -not $Divisor) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
        } else {
            $Pending = ($Request.blocks | Where-Object {$_ -match "^\d+?:\d+?:\d+?:\d+?:\d+?:(\d+?):"} | Foreach-Object {[int64]$Matches[1]} | Measure-Object -Sum).Sum / $Divisor
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
                Currency    = $Pool_Currency
                Balance     = $Request.stats.balance / $Divisor
                Pending     = $Pending
                Total       = $Request.stats.balance / $Divisor + $Pending
                Paid        = $Request.stats.paid / $Divisor
                Payouts     = @($i=0;$Request.payments | Where-Object {$_ -match "^(.+?):(\d+?):"} | Foreach-Object {[PSCustomObject]@{time=$Request.payments[$i+1];amount=$Matches[2] / $Divisor;txid=$Matches[1]};$i+=2})
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
}
