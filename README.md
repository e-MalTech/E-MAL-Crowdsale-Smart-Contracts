# E-MAL SMARTCONTRACT API - SAILSJS!


much faster testnet, later to be migrated to rinkeby, ropsten faucet hard to get so prefer former

# testrpc version
### Setup the server

> Create amazon ec2 ubuntu server instance
Open ports ssh, tcp: 8545, tcp:1337, under any, additionally open 80 and 443 if required.
Attach elastic IP
SSH into server with pem file
Linux users ``` chmod 400 xxx.pem ```

### Setup nodejs and tmux
```
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.8/install.sh | bash
. ~/.nvm/nvm.sh  
nvm install 8.11.2  
nvm install --lts
sudo apt-get install tmux
```
> *<kbd>Ctrl</kbd>+<kbd>b</kbd> go into tmux command mode, use before every key press
> <kbd>Ctrl</kbd>+<kbd>b</kbd> then <kbd>c</kbd> opens an extra window 
> <kbd>Ctrl</kbd>+<kbd>b</kbd> then <kbd>p</kbd> goes to previous window 
> <kbd>Ctrl</kbd>+<kbd>b</kbd> then <kbd>n</kbd> goes to next window*


### Setup testrpc

<kbd>Ctrl</kbd>+<kbd>b</kbd> then <kbd>c</kbd> opens an extra window 
```
npm install -g ethereumjs-testrpc
testrpc
```
> Connect metmask to elastic ip with port 8545
> Copy seedphrase and paste inside for reset 
> Use remix to deploy contracts on testrpc token, presale, crowdsale

### Setup sails app
<kbd>Ctrl</kbd>+<kbd>b</kbd> then <kbd>p</kbd> goes to previous window 
```
git clone https://serfasd@bitbucket.org/audacellc/emal-smartcontracts-sails-api.git
cd ema.....
npm install
npm install sails -g  
npm install bignumber.js --save
```
>Paste token, presale and crowdsale addresses from remix after deploy into ``` nano config/properties.js ```
### Production 
```
npm -g install forever
forever start -ae errors.log app.js --dev --port 1337
```
### geth testnet version connected to rinkeby


```
sudo apt-get install supervisor
sudo apt-get install software-properties-common  
sudo add-apt-repository -y ppa:ethereum/ethereum  
sudo apt-get update  
sudo apt-get install geth
```
```
mkdir testgeth
sudo nano /etc/supervisor/conf.d/geth.conf
```
```
[program:geth]
command=/usr/bin/geth --testnet --syncmode="light" --rpc --rpcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3 --cache=1024 --rpcport 8545 --rpcaddr 127.0.0.1 --rpccorsdomain "*" --datadir "/home/ubuntu/testgeth/"
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/geth.err.log
stdout_logfile=/var/log/supervisor/geth.out.log
```
```
sudo supervisorctl reload
sudo nano testgeth/genesis.json
```
```
{
"config": {
"chainId": 15,
"homesteadBlock": 0,
"eip155Block": 0,
"eip158Block": 0
},
"nonce": "0x0000000000000042",
"difficulty": "0x40",
"gasLimit": "21000000000000000",
"alloc": {
"0x95490e50a8b43348fa198bad08d4de211fb2b887": { "balance": "100000000000000000000000000" },
"0xa4f6f95b6cb36025dd09c9f5fe068e401951e963": { "balance": "10000000000000000000" }
}
}
```
```
geth --datadir "~/testgeth/" init testgeth/genesis.json
geth attach [http://127.0.0.1:8545](http://127.0.0.1:8545)
```