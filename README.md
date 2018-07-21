# [Testing Branch] E-MAL SMARTCONTRACT v2.0

## Testing values:

#### EmalToken
`startTimeForTransfers = now + 5 minutes;`

#### PublicSale and presale

`startTime = now;
endTime = startTime + 10 days;`

#### Vesting

`StandardTokenVesting vesting = new StandardTokenVesting(_beneficiary, now , 300 , 86400, true);`
cliff = 5 minutes
duration = 1 days
