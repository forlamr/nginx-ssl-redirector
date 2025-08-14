# Architettura Azure con Bicep

Questo progetto contiene un insieme di template Bicep che descrivono la seguente architettura Azure:

## Architettura

### Rete Virtuale (VNet)

- **VNet**: `vnet-{appname}-{locationshort}` con CIDR 10.0.0.0/16
- **Subnet**:
  - `default`: 10.0.0.0/24
  - `aca`: 10.0.1.0/24 (delegata a Microsoft.App/environments)
  - `AzureFirewallSubnet`: 10.0.2.0/26
  - `AzureFirewallManagementSubnet`: 10.0.2.64/26

### Container App Environment

- **Container App Environment**: `cae-{appname}-{locationshort}`
  - Tipo: Internal (BYOVNET - Bring Your Own Virtual Network)
  - Attestato sulla subnet "aca" (10.0.1.0/24)

### Container App

- **Container App**: `ca-nginx-forwarder-{appname}-{locationshort}`
  - Immagine: nginx:latest
  - Ingress: TCP su porta 8883
  - Aperto all'esterno dell'ambiente

### Azure Firewall

- **Azure Firewall**: `afw-{appname}-{locationshort}`
  - Tipo: Basic
  - IP Pubblico: `pip-fw-{appname}-{locationshort}`
  - IP Pubblico Management: `pip-fwmgmt-{appname}-{locationshort}`
  - Regole NAT: Forward dal pubblico porta 8883 → 10.0.1.57:8883

## Struttura File

```
iac2/
├── main.bicep                           # Template principale
├── main.parameters.json                 # Parametri di deployment
├── modules/
│   ├── vnet.bicep                       # Virtual Network e subnet
│   ├── firewall.bicep                   # Azure Firewall e IP pubblici
│   ├── container-app-environment.bicep  # Container App Environment
│   ├── container-app.bicep             # Container App nginx
│   └── nat-rules.bicep                 # Regole NAT per il firewall
└── README.md                           # Questo file
```

## Naming Convention

Tutti i nomi delle risorse seguono il formato: `{abbreviazione-risorsa}-{appname}-{locationshort}`

Dove:

- `appname`: Nome dell'applicazione (parametro)
- `locationshort`: Codice breve della location (parametro)

### Abbreviazioni Utilizzate

- `vnet`: Virtual Network
- `afw`: Azure Firewall
- `pip`: Public IP Address
- `cae`: Container App Environment
- `ca`: Container App

## Deployment

Per deployare l'infrastruttura:

```bash
# Creare un resource group
az group create --name rg-depolicify-itn --location italynorth

# Deployare l'infrastruttura
az deployment group create \
  --resource-group rg-depolicify-itn \
  --template-file main.bicep \
  --parameters main.parameters.json
```

## Parametri

I parametri del template principale sono:

- `appName`: Nome dell'applicazione (default: "depolicify")
- `locationShort`: Codice breve della location (default: "itn")
- `location`: Region Azure (default: "italynorth")

## Note

- Il Container App Environment è configurato come Internal, quindi non è direttamente accessibile da Internet
- Il traffico pubblico viene instradato attraverso Azure Firewall che effettua il NAT verso il Container App
