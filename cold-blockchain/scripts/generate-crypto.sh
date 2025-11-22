#!/bin/bash
#
# generate-crypto.sh - Generate cryptographic material for COLD Blockchain
# Hyperledger Fabric v2.5.14 - Archival Chain
#
# This script generates complete MSP and TLS certificates for:
# - OrdererOrg (1 orderer node)
# - LabOrg (1 peer node)
# - CourtOrg (1 peer node)
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
ORDERER_CA_URL="https://localhost:7154"
ORDERER_TLSCA_URL="https://localhost:8154"
LABORG_CA_URL="https://localhost:7155"
LABORG_TLSCA_URL="https://localhost:8155"
COURTORG_CA_URL="https://localhost:7156"
COURTORG_TLSCA_URL="https://localhost:8156"

CA_ADMIN="ca-admin"
CA_ADMIN_PW="ca-adminpw"
TLSCA_ADMIN="tls-ca-admin"
TLSCA_ADMIN_PW="tlscapw"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  COLD Blockchain Crypto Generation${NC}"
echo -e "${BLUE}  Archival Chain${NC}"
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
wait_for_ca "${COURTORG_CA_URL}" "CourtOrg Identity CA"
wait_for_ca "${COURTORG_TLSCA_URL}" "CourtOrg TLS CA"

sleep 3

# ============================================================================
# STEP 2: Get CA Root Certificates and Enroll CA Admins
# ============================================================================

print_section "STEP 2: Getting CA Root Certificates"

# Create CA directories if they don't exist
mkdir -p "${CRYPTO_DIR}/ordererOrganizations/ordererorg.cold.coc.com/ca"
mkdir -p "${CRYPTO_DIR}/ordererOrganizations/ordererorg.cold.coc.com/tlsca"
mkdir -p "${CRYPTO_DIR}/peerOrganizations/laborg.cold.coc.com/ca"
mkdir -p "${CRYPTO_DIR}/peerOrganizations/laborg.cold.coc.com/tlsca"
mkdir -p "${CRYPTO_DIR}/peerOrganizations/courtorg.cold.coc.com/ca"
mkdir -p "${CRYPTO_DIR}/peerOrganizations/courtorg.cold.coc.com/tlsca"

# Get CA root certs from containers
docker cp ca.ordererorg.cold.coc.com:/etc/hyperledger/fabric-ca-server/ca-cert.pem "${CRYPTO_DIR}/ordererOrganizations/ordererorg.cold.coc.com/ca/ca-cert.pem"
docker cp tlsca.ordererorg.cold.coc.com:/etc/hyperledger/fabric-ca-server/ca-cert.pem "${CRYPTO_DIR}/ordererOrganizations/ordererorg.cold.coc.com/tlsca/tls-cert.pem"
docker cp ca.laborg.cold.coc.com:/etc/hyperledger/fabric-ca-server/ca-cert.pem "${CRYPTO_DIR}/peerOrganizations/laborg.cold.coc.com/ca/ca-cert.pem"
docker cp tlsca.laborg.cold.coc.com:/etc/hyperledger/fabric-ca-server/ca-cert.pem "${CRYPTO_DIR}/peerOrganizations/laborg.cold.coc.com/tlsca/tls-cert.pem"
docker cp ca.courtorg.cold.coc.com:/etc/hyperledger/fabric-ca-server/ca-cert.pem "${CRYPTO_DIR}/peerOrganizations/courtorg.cold.coc.com/ca/ca-cert.pem"
docker cp tlsca.courtorg.cold.coc.com:/etc/hyperledger/fabric-ca-server/ca-cert.pem "${CRYPTO_DIR}/peerOrganizations/courtorg.cold.coc.com/tlsca/tls-cert.pem"

print_success "CA root certificates obtained"

# Fix ownership of all copied files
sudo chown -R $(whoami):$(whoami) "${CRYPTO_DIR}"
print_info "Fixed ownership of crypto materials"

# Enroll CA Admins
print_section "Enrolling CA Admins"

# OrdererOrg Identity CA Admin
export FABRIC_CA_CLIENT_HOME="${CRYPTO_DIR}/ordererOrganizations/ordererorg.cold.coc.com"
fabric-ca-client enroll -u https://${CA_ADMIN}:${CA_ADMIN_PW}@localhost:7154 \
    --caname ca.ordererorg.cold.coc.com \
    --tls.certfiles "${CRYPTO_DIR}/ordererOrganizations/ordererorg.cold.coc.com/ca/ca-cert.pem"
print_success "OrdererOrg Identity CA Admin enrolled"

# LabOrg Identity CA Admin
export FABRIC_CA_CLIENT_HOME="${CRYPTO_DIR}/peerOrganizations/laborg.cold.coc.com"
fabric-ca-client enroll -u https://${CA_ADMIN}:${CA_ADMIN_PW}@localhost:7155 \
    --caname ca.laborg.cold.coc.com \
    --tls.certfiles "${CRYPTO_DIR}/peerOrganizations/laborg.cold.coc.com/ca/ca-cert.pem"
print_success "LabOrg Identity CA Admin enrolled"

# CourtOrg Identity CA Admin
export FABRIC_CA_CLIENT_HOME="${CRYPTO_DIR}/peerOrganizations/courtorg.cold.coc.com"
fabric-ca-client enroll -u https://${CA_ADMIN}:${CA_ADMIN_PW}@localhost:7156 \
    --caname ca.courtorg.cold.coc.com \
    --tls.certfiles "${CRYPTO_DIR}/peerOrganizations/courtorg.cold.coc.com/ca/ca-cert.pem"
print_success "CourtOrg Identity CA Admin enrolled"

# ============================================================================
# STEP 3: Register Identities
# ============================================================================

print_section "STEP 3: Registering Identities"

# Register OrdererOrg identities
print_section "Registering OrdererOrg identities"
export FABRIC_CA_CLIENT_HOME="${CRYPTO_DIR}/ordererOrganizations/ordererorg.cold.coc.com"

fabric-ca-client register --caname ca.ordererorg.cold.coc.com \
    --id.name orderer.cold.coc.com \
    --id.secret ordererpw \
    --id.type orderer \
    --tls.certfiles "${CRYPTO_DIR}/ordererOrganizations/ordererorg.cold.coc.com/ca/ca-cert.pem"

fabric-ca-client register --caname ca.ordererorg.cold.coc.com \
    --id.name orderer-admin \
    --id.secret ordereradminpw \
    --id.type admin \
    --id.attrs "hf.Registrar.Roles=admin,hf.Revoker=true,admin=true:ecert" \
    --tls.certfiles "${CRYPTO_DIR}/ordererOrganizations/ordererorg.cold.coc.com/ca/ca-cert.pem"

print_success "OrdererOrg identities registered"

# Register LabOrg identities
print_section "Registering LabOrg identities"
export FABRIC_CA_CLIENT_HOME="${CRYPTO_DIR}/peerOrganizations/laborg.cold.coc.com"

fabric-ca-client register --caname ca.laborg.cold.coc.com \
    --id.name peer0.laborg.cold.coc.com \
    --id.secret peer0pw \
    --id.type peer \
    --tls.certfiles "${CRYPTO_DIR}/peerOrganizations/laborg.cold.coc.com/ca/ca-cert.pem"

fabric-ca-client register --caname ca.laborg.cold.coc.com \
    --id.name lab-admin \
    --id.secret labadminpw \
    --id.type admin \
    --id.attrs "hf.Registrar.Roles=admin,hf.Revoker=true,admin=true:ecert" \
    --tls.certfiles "${CRYPTO_DIR}/peerOrganizations/laborg.cold.coc.com/ca/ca-cert.pem"

fabric-ca-client register --caname ca.laborg.cold.coc.com \
    --id.name lab-user \
    --id.secret labuserpw \
    --id.type client \
    --tls.certfiles "${CRYPTO_DIR}/peerOrganizations/laborg.cold.coc.com/ca/ca-cert.pem"

print_success "LabOrg identities registered"

# Register CourtOrg identities
print_section "Registering CourtOrg identities"
export FABRIC_CA_CLIENT_HOME="${CRYPTO_DIR}/peerOrganizations/courtorg.cold.coc.com"

fabric-ca-client register --caname ca.courtorg.cold.coc.com \
    --id.name peer0.courtorg.cold.coc.com \
    --id.secret peer0pw \
    --id.type peer \
    --tls.certfiles "${CRYPTO_DIR}/peerOrganizations/courtorg.cold.coc.com/ca/ca-cert.pem"

fabric-ca-client register --caname ca.courtorg.cold.coc.com \
    --id.name court-admin \
    --id.secret courtadminpw \
    --id.type admin \
    --id.attrs "hf.Registrar.Roles=admin,hf.Revoker=true,admin=true:ecert" \
    --tls.certfiles "${CRYPTO_DIR}/peerOrganizations/courtorg.cold.coc.com/ca/ca-cert.pem"

fabric-ca-client register --caname ca.courtorg.cold.coc.com \
    --id.name court-user \
    --id.secret courtuserpw \
    --id.type client \
    --tls.certfiles "${CRYPTO_DIR}/peerOrganizations/courtorg.cold.coc.com/ca/ca-cert.pem"

print_success "CourtOrg identities registered"

# ============================================================================
# STEP 4: Build OrdererOrg MSP and Orderer Node
# ============================================================================

print_section "STEP 4: Building Orderer MSP"

# Enroll orderer admin
export FABRIC_CA_CLIENT_HOME="${CRYPTO_DIR}/ordererOrganizations/ordererorg.cold.coc.com"
mkdir -p users/orderer-admin
fabric-ca-client enroll -u https://orderer-admin:ordereradminpw@localhost:7154 \
    --caname ca.ordererorg.cold.coc.com \
    --tls.certfiles "${CRYPTO_DIR}/ordererOrganizations/ordererorg.cold.coc.com/ca/ca-cert.pem" \
    --mspdir users/orderer-admin/msp

# Copy admin cert to org MSP
cp "${CRYPTO_DIR}/ordererOrganizations/ordererorg.cold.coc.com/users/orderer-admin/msp/signcerts/"* \
   "${CRYPTO_DIR}/ordererOrganizations/ordererorg.cold.coc.com/msp/admincerts/orderer-admin-cert.pem"

# Copy CA certs to org MSP
cp "${CRYPTO_DIR}/ordererOrganizations/ordererorg.cold.coc.com/ca/ca-cert.pem" \
   "${CRYPTO_DIR}/ordererOrganizations/ordererorg.cold.coc.com/msp/cacerts/ca.ordererorg.cold.coc.com-cert.pem"
cp "${CRYPTO_DIR}/ordererOrganizations/ordererorg.cold.coc.com/tlsca/tls-cert.pem" \
   "${CRYPTO_DIR}/ordererOrganizations/ordererorg.cold.coc.com/msp/tlscacerts/tlsca.ordererorg.cold.coc.com-cert.pem"

# Enroll orderer node
mkdir -p orderers/orderer.cold.coc.com
fabric-ca-client enroll -u https://orderer.cold.coc.com:ordererpw@localhost:7154 \
    --caname ca.ordererorg.cold.coc.com \
    --tls.certfiles "${CRYPTO_DIR}/ordererOrganizations/ordererorg.cold.coc.com/ca/ca-cert.pem" \
    --mspdir orderers/orderer.cold.coc.com/msp

# Build orderer local MSP
ORDERER_MSP="${CRYPTO_DIR}/ordererOrganizations/ordererorg.cold.coc.com/orderers/orderer.cold.coc.com/msp"
cp "${CRYPTO_DIR}/ordererOrganizations/ordererorg.cold.coc.com/ca/ca-cert.pem" \
   "${ORDERER_MSP}/cacerts/ca.ordererorg.cold.coc.com-cert.pem"
cp "${CRYPTO_DIR}/ordererOrganizations/ordererorg.cold.coc.com/tlsca/tls-cert.pem" \
   "${ORDERER_MSP}/tlscacerts/tlsca.ordererorg.cold.coc.com-cert.pem"
cp "${CRYPTO_DIR}/ordererOrganizations/ordererorg.cold.coc.com/users/orderer-admin/msp/signcerts/"* \
   "${ORDERER_MSP}/admincerts/orderer-admin-cert.pem"

# Enroll orderer TLS
fabric-ca-client enroll -u https://orderer.cold.coc.com:ordererpw@localhost:8154 \
    --caname tlsca.ordererorg.cold.coc.com \
    --tls.certfiles "${CRYPTO_DIR}/ordererOrganizations/ordererorg.cold.coc.com/tlsca/tls-cert.pem" \
    --enrollment.profile tls \
    --csr.hosts orderer.cold.coc.com,localhost \
    --mspdir orderers/orderer.cold.coc.com/tls

# Rename TLS files
ORDERER_TLS="${CRYPTO_DIR}/ordererOrganizations/ordererorg.cold.coc.com/orderers/orderer.cold.coc.com/tls"
cp "${ORDERER_TLS}/signcerts/"* "${ORDERER_TLS}/server.crt"
cp "${ORDERER_TLS}/keystore/"* "${ORDERER_TLS}/server.key"
cp "${CRYPTO_DIR}/ordererOrganizations/ordererorg.cold.coc.com/tlsca/tls-cert.pem" "${ORDERER_TLS}/ca.crt"

print_success "Orderer MSP and TLS complete"

# ============================================================================
# STEP 5: Build LabOrg MSP and Peer Node
# ============================================================================

print_section "STEP 5: Building LabOrg Peer MSP"

# Enroll lab admin
export FABRIC_CA_CLIENT_HOME="${CRYPTO_DIR}/peerOrganizations/laborg.cold.coc.com"
mkdir -p users/lab-admin
fabric-ca-client enroll -u https://lab-admin:labadminpw@localhost:7155 \
    --caname ca.laborg.cold.coc.com \
    --tls.certfiles "${CRYPTO_DIR}/peerOrganizations/laborg.cold.coc.com/ca/ca-cert.pem" \
    --mspdir users/lab-admin/msp

# Copy to org MSP
cp "${CRYPTO_DIR}/peerOrganizations/laborg.cold.coc.com/users/lab-admin/msp/signcerts/"* \
   "${CRYPTO_DIR}/peerOrganizations/laborg.cold.coc.com/msp/admincerts/lab-admin-cert.pem"
cp "${CRYPTO_DIR}/peerOrganizations/laborg.cold.coc.com/ca/ca-cert.pem" \
   "${CRYPTO_DIR}/peerOrganizations/laborg.cold.coc.com/msp/cacerts/ca.laborg.cold.coc.com-cert.pem"
cp "${CRYPTO_DIR}/peerOrganizations/laborg.cold.coc.com/tlsca/tls-cert.pem" \
   "${CRYPTO_DIR}/peerOrganizations/laborg.cold.coc.com/msp/tlscacerts/tlsca.laborg.cold.coc.com-cert.pem"

# Enroll peer
mkdir -p peers/peer0.laborg.cold.coc.com
fabric-ca-client enroll -u https://peer0.laborg.cold.coc.com:peer0pw@localhost:7155 \
    --caname ca.laborg.cold.coc.com \
    --tls.certfiles "${CRYPTO_DIR}/peerOrganizations/laborg.cold.coc.com/ca/ca-cert.pem" \
    --mspdir peers/peer0.laborg.cold.coc.com/msp

# Build peer local MSP
PEER_MSP="${CRYPTO_DIR}/peerOrganizations/laborg.cold.coc.com/peers/peer0.laborg.cold.coc.com/msp"
cp "${CRYPTO_DIR}/peerOrganizations/laborg.cold.coc.com/ca/ca-cert.pem" \
   "${PEER_MSP}/cacerts/ca.laborg.cold.coc.com-cert.pem"
cp "${CRYPTO_DIR}/peerOrganizations/laborg.cold.coc.com/tlsca/tls-cert.pem" \
   "${PEER_MSP}/tlscacerts/tlsca.laborg.cold.coc.com-cert.pem"
cp "${CRYPTO_DIR}/peerOrganizations/laborg.cold.coc.com/users/lab-admin/msp/signcerts/"* \
   "${PEER_MSP}/admincerts/lab-admin-cert.pem"

# Enroll peer TLS
fabric-ca-client enroll -u https://peer0.laborg.cold.coc.com:peer0pw@localhost:8155 \
    --caname tlsca.laborg.cold.coc.com \
    --tls.certfiles "${CRYPTO_DIR}/peerOrganizations/laborg.cold.coc.com/tlsca/tls-cert.pem" \
    --enrollment.profile tls \
    --csr.hosts peer0.laborg.cold.coc.com,localhost \
    --mspdir peers/peer0.laborg.cold.coc.com/tls

# Rename TLS files
PEER_TLS="${CRYPTO_DIR}/peerOrganizations/laborg.cold.coc.com/peers/peer0.laborg.cold.coc.com/tls"
cp "${PEER_TLS}/signcerts/"* "${PEER_TLS}/server.crt"
cp "${PEER_TLS}/keystore/"* "${PEER_TLS}/server.key"
cp "${CRYPTO_DIR}/peerOrganizations/laborg.cold.coc.com/tlsca/tls-cert.pem" "${PEER_TLS}/ca.crt"

# Enroll lab user
mkdir -p users/lab-user
fabric-ca-client enroll -u https://lab-user:labuserpw@localhost:7155 \
    --caname ca.laborg.cold.coc.com \
    --tls.certfiles "${CRYPTO_DIR}/peerOrganizations/laborg.cold.coc.com/ca/ca-cert.pem" \
    --mspdir users/lab-user/msp

print_success "LabOrg Peer MSP and TLS complete"

# ============================================================================
# STEP 6: Build CourtOrg MSP and Peer Node
# ============================================================================

print_section "STEP 6: Building CourtOrg Peer MSP"

# Enroll court admin
export FABRIC_CA_CLIENT_HOME="${CRYPTO_DIR}/peerOrganizations/courtorg.cold.coc.com"
mkdir -p users/court-admin
fabric-ca-client enroll -u https://court-admin:courtadminpw@localhost:7156 \
    --caname ca.courtorg.cold.coc.com \
    --tls.certfiles "${CRYPTO_DIR}/peerOrganizations/courtorg.cold.coc.com/ca/ca-cert.pem" \
    --mspdir users/court-admin/msp

# Copy to org MSP
cp "${CRYPTO_DIR}/peerOrganizations/courtorg.cold.coc.com/users/court-admin/msp/signcerts/"* \
   "${CRYPTO_DIR}/peerOrganizations/courtorg.cold.coc.com/msp/admincerts/court-admin-cert.pem"
cp "${CRYPTO_DIR}/peerOrganizations/courtorg.cold.coc.com/ca/ca-cert.pem" \
   "${CRYPTO_DIR}/peerOrganizations/courtorg.cold.coc.com/msp/cacerts/ca.courtorg.cold.coc.com-cert.pem"
cp "${CRYPTO_DIR}/peerOrganizations/courtorg.cold.coc.com/tlsca/tls-cert.pem" \
   "${CRYPTO_DIR}/peerOrganizations/courtorg.cold.coc.com/msp/tlscacerts/tlsca.courtorg.cold.coc.com-cert.pem"

# Enroll peer
mkdir -p peers/peer0.courtorg.cold.coc.com
fabric-ca-client enroll -u https://peer0.courtorg.cold.coc.com:peer0pw@localhost:7156 \
    --caname ca.courtorg.cold.coc.com \
    --tls.certfiles "${CRYPTO_DIR}/peerOrganizations/courtorg.cold.coc.com/ca/ca-cert.pem" \
    --mspdir peers/peer0.courtorg.cold.coc.com/msp

# Build peer local MSP
PEER_MSP="${CRYPTO_DIR}/peerOrganizations/courtorg.cold.coc.com/peers/peer0.courtorg.cold.coc.com/msp"
cp "${CRYPTO_DIR}/peerOrganizations/courtorg.cold.coc.com/ca/ca-cert.pem" \
   "${PEER_MSP}/cacerts/ca.courtorg.cold.coc.com-cert.pem"
cp "${CRYPTO_DIR}/peerOrganizations/courtorg.cold.coc.com/tlsca/tls-cert.pem" \
   "${PEER_MSP}/tlscacerts/tlsca.courtorg.cold.coc.com-cert.pem"
cp "${CRYPTO_DIR}/peerOrganizations/courtorg.cold.coc.com/users/court-admin/msp/signcerts/"* \
   "${PEER_MSP}/admincerts/court-admin-cert.pem"

# Enroll peer TLS
fabric-ca-client enroll -u https://peer0.courtorg.cold.coc.com:peer0pw@localhost:8156 \
    --caname tlsca.courtorg.cold.coc.com \
    --tls.certfiles "${CRYPTO_DIR}/peerOrganizations/courtorg.cold.coc.com/tlsca/tls-cert.pem" \
    --enrollment.profile tls \
    --csr.hosts peer0.courtorg.cold.coc.com,localhost \
    --mspdir peers/peer0.courtorg.cold.coc.com/tls

# Rename TLS files
PEER_TLS="${CRYPTO_DIR}/peerOrganizations/courtorg.cold.coc.com/peers/peer0.courtorg.cold.coc.com/tls"
cp "${PEER_TLS}/signcerts/"* "${PEER_TLS}/server.crt"
cp "${PEER_TLS}/keystore/"* "${PEER_TLS}/server.key"
cp "${CRYPTO_DIR}/peerOrganizations/courtorg.cold.coc.com/tlsca/tls-cert.pem" "${PEER_TLS}/ca.crt"

# Enroll court user
mkdir -p users/court-user
fabric-ca-client enroll -u https://court-user:courtuserpw@localhost:7156 \
    --caname ca.courtorg.cold.coc.com \
    --tls.certfiles "${CRYPTO_DIR}/peerOrganizations/courtorg.cold.coc.com/ca/ca-cert.pem" \
    --mspdir users/court-user/msp

print_success "CourtOrg Peer MSP and TLS complete"

# ============================================================================
# STEP 7: Create TLS Trust Bundles
# ============================================================================

print_section "STEP 7: Creating TLS Trust Bundles"

TLS_BUNDLE_DIR="${CRYPTO_DIR}/tls-bundle"
mkdir -p "${TLS_BUNDLE_DIR}"

cat "${CRYPTO_DIR}/ordererOrganizations/ordererorg.cold.coc.com/tlsca/tls-cert.pem" \
    "${CRYPTO_DIR}/peerOrganizations/laborg.cold.coc.com/tlsca/tls-cert.pem" \
    "${CRYPTO_DIR}/peerOrganizations/courtorg.cold.coc.com/tlsca/tls-cert.pem" \
    > "${TLS_BUNDLE_DIR}/cold-chain-tls-ca-bundle.pem"

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
echo "  ✓ 3 Organizations configured (OrdererOrg, LabOrg, CourtOrg)"
echo "  ✓ 1 Orderer node with MSP and TLS"
echo "  ✓ 2 Peer nodes with MSP and TLS"
echo "  ✓ 5 Users enrolled (orderer-admin, lab-admin, lab-user, court-admin, court-user)"
echo "  ✓ TLS trust bundles created"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Verify crypto structure: tree -L 4 crypto-config/"
echo "  2. Start the network: docker-compose -f docker-compose-network.yaml up -d"
echo "  3. Create channel and join peers"
echo ""
