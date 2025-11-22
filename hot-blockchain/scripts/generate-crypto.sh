#!/bin/bash
#
# generate-crypto.sh - Generate cryptographic material for HOT Blockchain
# Hyperledger Fabric v2.5.14 - Active Investigation Chain
#
# This script generates complete MSP and TLS certificates for:
# - OrdererOrg (1 orderer node)
# - LabOrg (1 peer node)
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Base paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
CRYPTO_DIR="${BASE_DIR}/crypto-config"
CA_DIR="${BASE_DIR}/ca-config"

# Fabric CA client home
export FABRIC_CA_CLIENT_HOME="${BASE_DIR}/.fabric-ca-client"

# CA URLs and credentials
ORDERER_CA_URL="https://localhost:7054"
ORDERER_TLSCA_URL="https://localhost:8054"
LABORG_CA_URL="https://localhost:7055"
LABORG_TLSCA_URL="https://localhost:8055"

CA_ADMIN="ca-admin"
CA_ADMIN_PW="ca-adminpw"
TLSCA_ADMIN="tls-ca-admin"
TLSCA_ADMIN_PW="tlscapw"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  HOT Blockchain Crypto Generation${NC}"
echo -e "${BLUE}  Active Investigation Chain${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to print section headers
print_section() {
    echo ""
    echo -e "${YELLOW}>>> $1${NC}"
    echo ""
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}✗ ERROR: $1${NC}"
}

# Function to print info
print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Function to wait for CA to be ready
wait_for_ca() {
    local ca_url=$1
    local ca_name=$2
    local max_attempts=30
    local attempt=1

    print_section "Waiting for $ca_name to be ready..."

    while [ $attempt -le $max_attempts ]; do
        if curl -sSf -k "${ca_url}/cainfo" > /dev/null 2>&1; then
            print_success "$ca_name is ready!"
            return 0
        fi
        echo "Attempt $attempt/$max_attempts: $ca_name not ready yet..."
        sleep 2
        attempt=$((attempt + 1))
    done

    print_error "$ca_name failed to start after $max_attempts attempts"
    exit 1
}

# ============================================================================
# STEP 0: Clean up and prepare directories
# ============================================================================

print_section "STEP 0: Preparing crypto-config directories"

# Clean up any existing crypto-config with proper permissions
if [ -d "${CRYPTO_DIR}" ]; then
    print_info "Removing existing crypto-config directory..."
    # Use sudo to remove in case files are owned by root from previous Docker operations
    sudo rm -rf "${CRYPTO_DIR}"
fi

# Create fresh crypto-config directory with proper ownership
mkdir -p "${CRYPTO_DIR}"
print_success "Crypto-config directory prepared"

# ============================================================================
# STEP 1: Start Certificate Authority containers
# ============================================================================

print_section "STEP 1: Starting Certificate Authority containers"

cd "${BASE_DIR}"
docker-compose -f docker-compose-ca.yaml up -d

# Wait for all CAs to be ready
wait_for_ca "${ORDERER_CA_URL}" "OrdererOrg Identity CA"
wait_for_ca "${ORDERER_TLSCA_URL}" "OrdererOrg TLS CA"
wait_for_ca "${LABORG_CA_URL}" "LabOrg Identity CA"
wait_for_ca "${LABORG_TLSCA_URL}" "LabOrg TLS CA"

sleep 3

# ============================================================================
# STEP 2: Enroll CA Admins
# ============================================================================

print_section "STEP 2: Enrolling CA Admins"

# Create CA directories if they don't exist
mkdir -p "${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com/ca"
mkdir -p "${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com/tlsca"
mkdir -p "${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com/ca"
mkdir -p "${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com/tlsca"

# Get CA root certs
curl -sSf -k ${ORDERER_CA_URL}/cainfo | jq -r '.result.CAChain' | base64 -d > "${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com/ca/ca-cert.pem" 2>/dev/null || \
  { docker cp ca.ordererorg.hot.coc.com:/etc/hyperledger/fabric-ca-server/ca-cert.pem "${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com/ca/ca-cert.pem" && \
    sudo chown -R $(whoami):$(whoami) "${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com/ca"; }

curl -sSf -k ${ORDERER_TLSCA_URL}/cainfo | jq -r '.result.CAChain' | base64 -d > "${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com/tlsca/tls-cert.pem" 2>/dev/null || \
  { docker cp tlsca.ordererorg.hot.coc.com:/etc/hyperledger/fabric-ca-server/ca-cert.pem "${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com/tlsca/tls-cert.pem" && \
    sudo chown -R $(whoami):$(whoami) "${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com/tlsca"; }

curl -sSf -k ${LABORG_CA_URL}/cainfo | jq -r '.result.CAChain' | base64 -d > "${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com/ca/ca-cert.pem" 2>/dev/null || \
  { docker cp ca.laborg.hot.coc.com:/etc/hyperledger/fabric-ca-server/ca-cert.pem "${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com/ca/ca-cert.pem" && \
    sudo chown -R $(whoami):$(whoami) "${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com/ca"; }

curl -sSf -k ${LABORG_TLSCA_URL}/cainfo | jq -r '.result.CAChain' | base64 -d > "${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com/tlsca/tls-cert.pem" 2>/dev/null || \
  { docker cp tlsca.laborg.hot.coc.com:/etc/hyperledger/fabric-ca-server/ca-cert.pem "${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com/tlsca/tls-cert.pem" && \
    sudo chown -R $(whoami):$(whoami) "${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com/tlsca"; }

print_success "CA root certificates obtained"

# Ensure all crypto-config is owned by current user
sudo chown -R $(whoami):$(whoami) "${CRYPTO_DIR}"

# OrdererOrg Identity CA Admin
print_section "Enrolling OrdererOrg Identity CA Admin"
export FABRIC_CA_CLIENT_HOME="${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com"
fabric-ca-client enroll -u https://${CA_ADMIN}:${CA_ADMIN_PW}@localhost:7054 \
    --caname ca.ordererorg.hot.coc.com \
    --tls.certfiles "${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com/ca/ca-cert.pem"
print_success "OrdererOrg Identity CA Admin enrolled"

# LabOrg Identity CA Admin
print_section "Enrolling LabOrg Identity CA Admin"
export FABRIC_CA_CLIENT_HOME="${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com"
fabric-ca-client enroll -u https://${CA_ADMIN}:${CA_ADMIN_PW}@localhost:7055 \
    --caname ca.laborg.hot.coc.com \
    --tls.certfiles "${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com/ca/ca-cert.pem"
print_success "LabOrg Identity CA Admin enrolled"

# ============================================================================
# STEP 3: Register Identities
# ============================================================================

print_section "STEP 3: Registering Identities"

# Register OrdererOrg identities
print_section "Registering OrdererOrg identities"
export FABRIC_CA_CLIENT_HOME="${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com"

fabric-ca-client register --caname ca.ordererorg.hot.coc.com \
    --id.name orderer.hot.coc.com \
    --id.secret ordererpw \
    --id.type orderer \
    --tls.certfiles "${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com/ca/ca-cert.pem"

fabric-ca-client register --caname ca.ordererorg.hot.coc.com \
    --id.name orderer-admin \
    --id.secret ordereradminpw \
    --id.type admin \
    --id.attrs "hf.Registrar.Roles=admin,hf.Revoker=true,admin=true:ecert" \
    --tls.certfiles "${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com/ca/ca-cert.pem"

print_success "OrdererOrg identities registered"

# Register LabOrg identities
print_section "Registering LabOrg identities"
export FABRIC_CA_CLIENT_HOME="${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com"

fabric-ca-client register --caname ca.laborg.hot.coc.com \
    --id.name peer0.laborg.hot.coc.com \
    --id.secret peer0pw \
    --id.type peer \
    --tls.certfiles "${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com/ca/ca-cert.pem"

fabric-ca-client register --caname ca.laborg.hot.coc.com \
    --id.name lab-admin \
    --id.secret labadminpw \
    --id.type admin \
    --id.attrs "hf.Registrar.Roles=admin,hf.Revoker=true,admin=true:ecert" \
    --tls.certfiles "${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com/ca/ca-cert.pem"

fabric-ca-client register --caname ca.laborg.hot.coc.com \
    --id.name lab-user \
    --id.secret labuserpw \
    --id.type client \
    --tls.certfiles "${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com/ca/ca-cert.pem"

print_success "LabOrg identities registered"

# ============================================================================
# STEP 4: Enroll Orderer Identity and Build MSP
# ============================================================================

print_section "STEP 4: Building Orderer MSP"

# Enroll orderer admin
print_section "Enrolling orderer admin"
export FABRIC_CA_CLIENT_HOME="${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com"
mkdir -p users/orderer-admin
fabric-ca-client enroll -u https://orderer-admin:ordereradminpw@localhost:7054 \
    --caname ca.ordererorg.hot.coc.com \
    --tls.certfiles "${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com/ca/ca-cert.pem" \
    --mspdir users/orderer-admin/msp

# Copy admin cert to org MSP admincerts
cp "${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com/users/orderer-admin/msp/signcerts/"* \
   "${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com/msp/admincerts/orderer-admin-cert.pem"

# Copy CA cert to org MSP
cp "${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com/ca/ca-cert.pem" \
   "${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com/msp/cacerts/ca.ordererorg.hot.coc.com-cert.pem"

# Copy TLS CA cert to org MSP
cp "${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com/tlsca/tls-cert.pem" \
   "${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com/msp/tlscacerts/tlsca.ordererorg.hot.coc.com-cert.pem"

print_success "OrdererOrg MSP built"

# Enroll orderer node
print_section "Enrolling orderer node"
export FABRIC_CA_CLIENT_HOME="${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com"
mkdir -p orderers/orderer.hot.coc.com
fabric-ca-client enroll -u https://orderer.hot.coc.com:ordererpw@localhost:7054 \
    --caname ca.ordererorg.hot.coc.com \
    --tls.certfiles "${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com/ca/ca-cert.pem" \
    --mspdir orderers/orderer.hot.coc.com/msp

# Build orderer local MSP
ORDERER_MSP="${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com/orderers/orderer.hot.coc.com/msp"

# Copy CA cert
cp "${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com/ca/ca-cert.pem" \
   "${ORDERER_MSP}/cacerts/ca.ordererorg.hot.coc.com-cert.pem"

# Copy TLS CA cert
cp "${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com/tlsca/tls-cert.pem" \
   "${ORDERER_MSP}/tlscacerts/tlsca.ordererorg.hot.coc.com-cert.pem"

# Copy admin cert
cp "${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com/users/orderer-admin/msp/signcerts/"* \
   "${ORDERER_MSP}/admincerts/orderer-admin-cert.pem"

# Enroll orderer TLS cert
print_section "Enrolling orderer TLS certificate"
export FABRIC_CA_CLIENT_HOME="${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com"
fabric-ca-client enroll -u https://orderer.hot.coc.com:ordererpw@localhost:8054 \
    --caname tlsca.ordererorg.hot.coc.com \
    --tls.certfiles "${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com/tlsca/tls-cert.pem" \
    --enrollment.profile tls \
    --csr.hosts orderer.hot.coc.com,localhost \
    --mspdir orderers/orderer.hot.coc.com/tls

# Rename TLS files to standard names
ORDERER_TLS="${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com/orderers/orderer.hot.coc.com/tls"
cp "${ORDERER_TLS}/signcerts/"* "${ORDERER_TLS}/server.crt"
cp "${ORDERER_TLS}/keystore/"* "${ORDERER_TLS}/server.key"
cp "${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com/tlsca/tls-cert.pem" "${ORDERER_TLS}/ca.crt"

print_success "Orderer MSP and TLS complete"

# ============================================================================
# STEP 5: Enroll Peer Identity and Build MSP
# ============================================================================

print_section "STEP 5: Building LabOrg Peer MSP"

# Enroll lab admin
print_section "Enrolling lab admin"
export FABRIC_CA_CLIENT_HOME="${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com"
mkdir -p users/lab-admin
fabric-ca-client enroll -u https://lab-admin:labadminpw@localhost:7055 \
    --caname ca.laborg.hot.coc.com \
    --tls.certfiles "${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com/ca/ca-cert.pem" \
    --mspdir users/lab-admin/msp

# Copy admin cert to org MSP admincerts
cp "${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com/users/lab-admin/msp/signcerts/"* \
   "${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com/msp/admincerts/lab-admin-cert.pem"

# Copy CA cert to org MSP
cp "${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com/ca/ca-cert.pem" \
   "${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com/msp/cacerts/ca.laborg.hot.coc.com-cert.pem"

# Copy TLS CA cert to org MSP
cp "${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com/tlsca/tls-cert.pem" \
   "${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com/msp/tlscacerts/tlsca.laborg.hot.coc.com-cert.pem"

print_success "LabOrg MSP built"

# Enroll peer node
print_section "Enrolling peer0.laborg.hot.coc.com"
export FABRIC_CA_CLIENT_HOME="${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com"
mkdir -p peers/peer0.laborg.hot.coc.com
fabric-ca-client enroll -u https://peer0.laborg.hot.coc.com:peer0pw@localhost:7055 \
    --caname ca.laborg.hot.coc.com \
    --tls.certfiles "${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com/ca/ca-cert.pem" \
    --mspdir peers/peer0.laborg.hot.coc.com/msp

# Build peer local MSP
PEER_MSP="${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com/peers/peer0.laborg.hot.coc.com/msp"

# Copy CA cert
cp "${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com/ca/ca-cert.pem" \
   "${PEER_MSP}/cacerts/ca.laborg.hot.coc.com-cert.pem"

# Copy TLS CA cert
cp "${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com/tlsca/tls-cert.pem" \
   "${PEER_MSP}/tlscacerts/tlsca.laborg.hot.coc.com-cert.pem"

# Copy admin cert
cp "${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com/users/lab-admin/msp/signcerts/"* \
   "${PEER_MSP}/admincerts/lab-admin-cert.pem"

# Enroll peer TLS cert
print_section "Enrolling peer TLS certificate"
export FABRIC_CA_CLIENT_HOME="${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com"
fabric-ca-client enroll -u https://peer0.laborg.hot.coc.com:peer0pw@localhost:8055 \
    --caname tlsca.laborg.hot.coc.com \
    --tls.certfiles "${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com/tlsca/tls-cert.pem" \
    --enrollment.profile tls \
    --csr.hosts peer0.laborg.hot.coc.com,localhost \
    --mspdir peers/peer0.laborg.hot.coc.com/tls

# Rename TLS files to standard names
PEER_TLS="${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com/peers/peer0.laborg.hot.coc.com/tls"
cp "${PEER_TLS}/signcerts/"* "${PEER_TLS}/server.crt"
cp "${PEER_TLS}/keystore/"* "${PEER_TLS}/server.key"
cp "${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com/tlsca/tls-cert.pem" "${PEER_TLS}/ca.crt"

print_success "Peer0 MSP and TLS complete"

# Enroll lab user
print_section "Enrolling lab user"
export FABRIC_CA_CLIENT_HOME="${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com"
mkdir -p users/lab-user
fabric-ca-client enroll -u https://lab-user:labuserpw@localhost:7055 \
    --caname ca.laborg.hot.coc.com \
    --tls.certfiles "${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com/ca/ca-cert.pem" \
    --mspdir users/lab-user/msp

print_success "Lab user enrolled"

# ============================================================================
# STEP 6: Create TLS Trust Bundles
# ============================================================================

print_section "STEP 6: Creating TLS Trust Bundles"

# Create combined TLS CA bundle for mutual trust
TLS_BUNDLE_DIR="${CRYPTO_DIR}/tls-bundle"
mkdir -p "${TLS_BUNDLE_DIR}"

cat "${CRYPTO_DIR}/ordererOrganizations/ordererorg.hot.coc.com/tlsca/tls-cert.pem" \
    "${CRYPTO_DIR}/peerOrganizations/laborg.hot.coc.com/tlsca/tls-cert.pem" \
    > "${TLS_BUNDLE_DIR}/hot-chain-tls-ca-bundle.pem"

print_success "TLS trust bundle created"

# ============================================================================
# Summary
# ============================================================================

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Crypto Generation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Summary:${NC}"
echo "  ✓ 2 Organizations configured (OrdererOrg, LabOrg)"
echo "  ✓ 1 Orderer node with MSP and TLS"
echo "  ✓ 1 Peer node with MSP and TLS"
echo "  ✓ 3 Users enrolled (orderer-admin, lab-admin, lab-user)"
echo "  ✓ TLS trust bundles created"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Verify crypto structure: tree -L 4 crypto-config/"
echo "  2. Start the network: docker-compose -f docker-compose-network.yaml up -d"
echo "  3. Create channel and join peers"
echo ""
