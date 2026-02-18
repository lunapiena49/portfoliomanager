# Formati CSV di esportazione portfolio dei principali broker mondiali

L'analisi dei formati di esportazione CSV rivela **significative differenze tra broker USA ed europei**: i broker americani utilizzano uniformemente il separatore virgola e date MM/DD/YYYY, mentre quelli europei mostrano maggiore variabilità con punto e virgola, date DD-MM-YYYY e alcuni (eToro, Saxo Bank) che esportano solo in Excel richiedendo conversione manuale.

---

## Broker USA: uniformità nel formato americano standard

### TD Ameritrade (ora integrato in Schwab)

**Transaction History CSV:**
```
DATE,TRANSACTION ID,DESCRIPTION,QUANTITY,SYMBOL,PRICE,COMMISSION,AMOUNT,NET CASH BALANCE,REG FEE,SHORT-TERM RDM FEE,FUND REDEMPTION FEE,DEFERRED SALES CHARGE
```

| Caratteristica | Valore |
|----------------|--------|
| Separatore | Virgola (,) |
| Decimali | Punto (1,234.56) |
| Date | MM/DD/YYYY |
| Marker speciale | `***END OF FILE***` alla fine del file |
| Quote | Nessuna |

**Esempio riga:**
```
01/03/2019,99999999999,CASH ALTERNATIVES PURCHASE,,,,,-999.00,0.00,,,,
```

---

### Fidelity

**Positions CSV - Header esatti:**
```
Account Number,Account Name,Symbol,Description,Quantity,Last Price,Last Price Change,Current Value,Today's Gain/Loss Dollar,Today's Gain/Loss Percent,Total Gain/Loss Dollar,Total Gain/Loss Percent,Percent Of Account,Cost Basis,Cost Basis Per Share,Type
```

| Caratteristica | Valore |
|----------------|--------|
| Separatore | Virgola (,) |
| Decimali | Punto con simbolo $ (es. $441.41) |
| Date | N/A (snapshot posizioni) |
| BOM | UTF-8 BOM all'inizio (﻿) |
| Footer | 2 righe disclaimer legale alla fine |

**Caratteristiche speciali:**
- Prefissi +/- per gain/loss (es. `+$111.14`, `-$18.98`)
- Simbolo % per percentuali (es. `+4.44%`)

**Esempio riga:**
```csv
Z1234567,INDIVIDUAL + TOD,ABC,ABC Stock,41.28,$441.41,+$4.24,$1428.42,+$111.14,+4.44%,+$48.41,+0.84%,11.91%,$1440.09,$418.14,Cash
```

---

### Charles Schwab

**Transaction History CSV - Header:**
```
"Date","Action","Symbol","Description","Quantity","Price","Fees & Comm","Amount"
```

**Metadata iniziale (prime 2 righe):**
```
Transactions for account XXXX-9999 as of 06/17/2018 14:50:44 ET
From 01/01/2018 to 06/17/2018
```

| Caratteristica | Valore |
|----------------|--------|
| Separatore | Virgola (,) |
| Decimali | Punto con $ tra virgolette ("$26.37") |
| Date | MM/DD/YYYY |
| Quote | Tutti i campi in doppi apici |
| Header metadata | 2-3 righe prima delle colonne |

**Action types:** Buy, Sell, Reinvest Shares, Reinvest Dividend, Cash Dividend, Credit Interest, Long Term Cap Gain, Short Term Cap Gain, Wire Received, ADR Mgmt Fee

---

### E*TRADE (Morgan Stanley)

**Positions CSV - Header core:**
```
Symbol,Price Paid $,Qty #,Description,Last Price,Market Value,Day Change,Total Gain/Loss
```

**Transactions CSV (file: DownloadTxnHistory.csv):**
```
TransactionDate,Symbol,SecurityType,Description,TransactionType,Quantity,Price,Amount,Commission,Fee
```

| Caratteristica | Valore |
|----------------|--------|
| Separatore | Virgola (,) |
| Decimali | Punto (1,234.56) |
| Date | MM/DD/YYYY |
| Formati export | CSV e XLSX disponibili |

---

### Robinhood

**Activity Report CSV - Header esatti:**
```
Activity Date,Process Date,Settle Date,Instrument,Description,Trans Code,Quantity,Price,Amount
```

| Caratteristica | Valore |
|----------------|--------|
| Separatore | Virgola (,) |
| Decimali | Punto con $ ("$53.85") |
| Date | M/DD/YYYY o MM/DD/YYYY |
| Quote | Tutti i campi in doppi apici |
| Negativi | Parentesi per outflow: ($43.64) |

**Trans Code values:** Buy, Sell, CDIV (Cash dividend)

**Esempio riga:**
```csv
"9/18/2023","9/18/2023","9/20/2023","O","Realty Income CUSIP: 756109104 Dividend Reinvestment","Buy","0.810399","$53.85","($43.64)"
```

**Limitazioni:** Solo 1 anno di storico, report generati in 2-24 ore.

---

### Vanguard

**Brokerage Holdings CSV:**
```
Account Number,Investment Name,Symbol,Shares,Share Price,Total Value
```

**Transaction History CSV:**
```
Account Number,Trade Date,Settlement Date,Transaction Type,Transaction Description,Investment Name,Symbol,Shares,Share Price,Principal Amount,Commission,Fees,Net Amount,Accrued Interest,Account Type
```

| Caratteristica | Valore |
|----------------|--------|
| Separatore | Virgola (,) |
| Decimali | Punto con simbolo $ |
| Date | MM/DD/YYYY |
| Filename | `ofxdownload.csv` (può scaricarsi come .csv.xls) |

**Struttura file:** Prima sezione Holdings, poi sezione Transactions. Limite storico: **18 mesi**.

---

## Broker europei: maggiore variabilità nei formati

### DEGIRO (Paesi Bassi)

**Account Statement CSV - Header:**
```
Date,Time,Value date,Product,ISIN,Description,FX,Change,,Balance,,Order ID
```

**Transactions CSV - Header:**
```
Date,Time,Product,ISIN,Exchange,Execution Venue,Number,Price,,Local Value,,Value,,Exchange Rate,,Transaction Costs,,Total,,Order ID
```

| Caratteristica | Valore |
|----------------|--------|
| Separatore | Virgola (,) |
| Decimali | Europeo (127,54) nelle versioni localizzate, punto nell'export inglese |
| Date | DD-MM-YYYY (es. 11-10-2024) |
| Ora | HH:MM (24h) |
| Order ID | UUID (es. 833b4a2b-4dde-452a-84be-5fd61ab8d3e4) |

**Nota importante:** Colonne vuote tra alcuni campi (marcate da `,,`)

**Esempio riga:**
```
11-10-2024,13:27,11-10-2024,VANGUARD FTSE ALL-WORLD UCITS ETF,IE00BK5BQT80,Buy 8 Vanguard FTSE All-World UCITS ETF USD Acc@127.54 EUR (IE00BK5BQT80),,EUR,-1020.32,EUR,14.28,833b4a2b-4dde-452a-84be-5fd61ab8d3e4
```

**Description values:** `Buy X [Product]@[Price] [Currency] (ISIN)`, `Sell X...`, `Dividend`, `Dividend Tax`, `DEGIRO Transaction and/or third party fees`

---

### Trading 212 (UK)

**Transaction History CSV - Header completo (18 colonne):**
```
Action,Time,ISIN,Ticker,Name,No. of shares,Price / share,Currency (Price / share),Exchange rate,Result (EUR),Total (EUR),Withholding tax,Currency (Withholding tax),Charge amount (EUR),Stamp duty reserve tax (EUR),Notes,ID,Currency conversion fee (EUR)
```

| Caratteristica | Valore |
|----------------|--------|
| Separatore | Virgola (,) |
| Decimali | Punto (1.50) |
| Date | ISO 8601 (2024-01-15T10:30:00Z) |
| Valuta base | Indicata nell'header (EUR), (GBP) |

**⚠️ Attenzione critica:** Le colonne sono **dinamiche** - appaiono/scompaiono in base ai tipi di transazione nel periodo esportato. L'ordine delle colonne può cambiare tra export diversi.

**Action values:** Market buy, Market sell, Limit buy, Limit sell, Dividend (Ordinary), Deposit, Withdrawal, Interest on cash, Currency conversion

**Limitazioni:** Solo account "Invest" (NO CFD), finestre massime di 12 mesi.

---

### Saxo Bank (Danimarca)

**⚠️ FORMATO NATIVO: Excel (.xlsx), NON CSV**

Richiede conversione manuale a CSV.

**Column Headers tipici (dopo conversione):**
```
Trade Date,Value Date,Instrument,ISIN,Trade Type,Amount,Price,Currency,Exchange Rate,Commission,Total,Account
```

| Caratteristica | Valore |
|----------------|--------|
| Formato nativo | Excel (.xlsx) |
| Separatore (dopo conversione) | Definito dall'utente |
| Date | DD-MM-YYYY o YYYY-MM-DD (dipende da locale) |
| Decimali | Varia per regione |

**Report disponibili:** Account Statement, Portfolio Report, Aggregated Amounts, Dividends, Account Interest Details

**Export path:** Profile → Transaction overview → Export → Excel

---

## Broker globali/fintech

### XTB (Polonia)

**Cash Operations CSV - Header:**
```
ID;Symbol;Type;Time;Comment;Amount
```

**Closed Positions report - Header esteso:**
```
ID;Position;Symbol;Type;Open Time;Close Time;Open Rate;Close Rate;Commission;Rollover;Profit;Net Profit;Comment
```

| Caratteristica | Valore |
|----------------|--------|
| **Separatore** | **Punto e virgola (;)** |
| Decimali | Punto (.) - può essere virgola in locale polacco |
| Date | DD.MM.YYYY HH:MM:SS |
| Simboli | TICKER.EXCHANGE (es. AAPL.US, MSFT.US) |

**Nota:** Formato cambiato a marzo 2025 - ora usa Excel con tabs separati.

**Esempio riga:**
```
123456;AAPL.US;Stocks/ETF purchase;15.03.2024 10:30:25;buy 0.5 at 175.50;-87.75
```

---

### eToro (Israele/Cipro)

**⚠️ FORMATO NATIVO: Excel (.xlsx), NON CSV**

L'export contiene **multiple sheets** nel file Excel:

**Sheet "Closed Positions" - Header:**
```
Position ID,Action,Amount,Units,Open Rate,Close Rate,Spread,Profit,Open Date,Close Date,Take Profit Rate,Stop Loss Rate,Rollover Fees And Dividends,Copied From,Type,ISIN,Notes
```

**Sheet "Account Activity" - Header:**
```
Date,Account Balance,Type,Details,Position ID,Amount,Realized Equity Change,Realized Equity,NWA
```

| Caratteristica | Valore |
|----------------|--------|
| Formato nativo | Excel (.xlsx) con multi-sheet |
| Separatore (dopo conversione) | Virgola (,) |
| Decimali | Punto (.) |
| Date | DD/MM/YYYY HH:MM:SS |
| Valuta | USD |

**Colonne esclusive eToro:**
- `Copied From` - traccia fonte copy trading
- `Spread` - costo transazione (modello spread-based)
- `Type` - asset class (Stocks, CFD, Crypto, ETF)

**Esempio riga (Closed Positions):**
```
123456789,Buy,500.00,2.5,175.50,182.30,0.15,16.85,01/03/2024 09:30:00,15/03/2024 14:45:00,200.00,160.00,0.00,,Stocks,US0378331005,
```

---

### Revolut Trading (UK)

**Account Statement CSV - Header:**
```
Trade Date,Settle Date,Currency,Activity Type,Symbol / Description,Symbol,Description,Quantity,Price,Amount
```

| Caratteristica | Valore |
|----------------|--------|
| Separatore | Virgola (,) |
| Decimali | Punto (.) |
| Date | YYYY-MM-DD (ISO) |
| Negativi | Parentesi: (455.75) |
| Valuta | Colonna per riga (tipicamente USD) |

**Activity Type values:** BUY, SELL, DIV (Dividend), CDEP (Cash deposit), CSD/SSP (Stock split)

**Esempio riga:**
```
2024-03-15,2024-03-18,USD,BUY,AAPL - Apple Inc,AAPL,Apple Inc,2.5,175.50,438.75
```

**Nota:** Fornito tramite DriveWealth LLC. Export CSV/Excel disponibile dal giugno 2021.

---

## Tabella comparativa riassuntiva

| Broker | Separatore | Decimali | Formato date | Export nativo | Note speciali |
|--------|------------|----------|--------------|---------------|---------------|
| TD Ameritrade | , | . (US) | MM/DD/YYYY | CSV | `***END OF FILE***` marker |
| Fidelity | , | . con $ | MM/DD/YYYY | CSV | UTF-8 BOM, footer disclaimer |
| Charles Schwab | , | . con $ | MM/DD/YYYY | CSV | Campi quotati, header metadata |
| E*TRADE | , | . (US) | MM/DD/YYYY | CSV/XLSX | Colonne customizzabili |
| Robinhood | , | . con $ | M/DD/YYYY | CSV | Parentesi per negativi, max 1 anno |
| Vanguard | , | . con $ | MM/DD/YYYY | CSV | Max 18 mesi storico |
| **DEGIRO** | , | , (EU) / . (EN) | **DD-MM-YYYY** | CSV | UUID per Order ID |
| **Trading 212** | , | . | **ISO 8601** | CSV | ⚠️ Colonne dinamiche |
| **Saxo Bank** | N/A | Varia | DD-MM-YYYY | **Excel** | Richiede conversione |
| **XTB** | **;** | . | **DD.MM.YYYY** | CSV/Excel | Formato cambiato 2025 |
| **eToro** | , | . | DD/MM/YYYY | **Excel** | Multi-sheet, copy trading |
| **Revolut** | , | . | **YYYY-MM-DD** | CSV | Formato più pulito |

---

## Considerazioni per l'implementazione di parser

I **problemi più critici** da gestire nell'implementazione:

1. **Trading 212** presenta il formato più imprevedibile con colonne che appaiono/scompaiono dinamicamente - richiede parsing flessibile basato sugli header
2. **Saxo Bank e eToro** richiedono pre-processing per conversione da Excel a CSV
3. **XTB** è l'unico broker che usa **punto e virgola** come separatore
4. **Fidelity** include BOM UTF-8 e righe footer che devono essere ignorate
5. **Schwab** ha righe metadata prima degli header effettivi delle colonne

Per parser robusti, consiglio di riferirsi ai repository GitHub **Export-To-Ghostfolio** (github.com/dickwolff/Export-To-Ghostfolio) e **Portfolio Performance importers** che gestiscono attivamente questi formati con aggiornamenti regolari.