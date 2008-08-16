/*
 * Copyright (C) 2007 by Massimiliano Mirra
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
 *
 * Author: Massimiliano Mirra, <bard [at] hyperstruct [dot] net>
 */


#include "pk11pub.h"
#include "nspr.h"
#include "nss.h"
#include "keyhi.h"
#include "plbase64.h"

#define MAXSIZE 32768


DERTemplate SECAlgorithmIDTemplate[] = {
    { DER_SEQUENCE,
      0, NULL, sizeof(SECAlgorithmID) },
    { DER_OBJECT_ID,
      offsetof(SECAlgorithmID,algorithm), },
    { DER_OPTIONAL | DER_ANY,
      offsetof(SECAlgorithmID,parameters), },
    { 0, }
};

DERTemplate CERTSignatureDataTemplate[] =
{
    { DER_SEQUENCE,
          0, NULL, sizeof(CERTSignedData) },
    { DER_INLINE,
          offsetof(CERTSignedData,signatureAlgorithm),
          SECAlgorithmIDTemplate, },
    { DER_BIT_STRING,
          offsetof(CERTSignedData,signature), },
    { 0, }
};

int main(int argc, char *argv[])
{
    PRBool readOnly       = PR_FALSE;    
    PK11SlotInfo *slot    = NULL;
    SECOidTag alg         = SEC_OID_PKCS1_SHA512_WITH_RSA_ENCRYPTION;
    SECStatus rv;
    char *progName;
    SECKEYPrivateKey *key;
    char data[MAXSIZE];
    int dataLen;

    progName = argv[0];
    if(argc != 2) {
        fprintf(stderr, "Usage: %s <mccoy profile dir>\n", progName);
        goto shutdown;
    }

    char *configDirectory = argv[1];

    // Initialize NSS

    rv = NSS_Initialize(configDirectory, "", "", "secmod.db", 0);
    if(rv != SECSuccess) {
	    SECU_PrintPRandOSError(progName);
	    rv = SECFailure;
	    goto shutdown;
    }
    SECU_RegisterDynamicOids();

    // Exit if keys are protected.
    
    slot = PK11_GetInternalKeySlot();
    if(PK11_NeedUserInit(slot)) {
        fprintf(stderr, "Error: needs user init.\n");
        rv = SECFailure;
        goto shutdown;
    }

    if(PK11_NeedLogin(slot)) {
        fprintf(stderr, "Error: password-protected key databases not supported.\n");
        rv = SECFailure;
        goto shutdown;
    }
    
    // Retrieve first key in database

    SECKEYPrivateKeyList *list;
    SECKEYPrivateKeyListNode *node;
    list = PK11_ListPrivKeysInSlot(slot, NULL, NULL);
    if(!list) {
        fprintf(stderr, "Error: no keys found.\n");
        rv = SECFailure;
        goto shutdown;
    }
    node = PRIVKEY_LIST_HEAD(list);
    key = SECKEY_CopyPrivateKey(node->key);
    SECKEY_DestroyPrivateKeyList(list);

    // Read data

    dataLen = fread(data, 1, MAXSIZE, stdin);

    // Create signature

    SECItem signature;
    PORT_Memset(&signature, 0, sizeof(SECItem));
    
    CERTSignedData sd;
    PORT_Memset(&sd, 0, sizeof(CERTSignedData));
    
    rv = SEC_SignData(&(sd.signature), data, dataLen, key, alg);
    if(rv != SECSuccess) {
        fprintf(stderr, "Error: could not sign data.\n");
        goto shutdown;
    }
    sd.signature.len = sd.signature.len << 3;

    PRArenaPool *arena;
    arena = PORT_NewArena(DER_DEFAULT_CHUNKSIZE);
    if(!arena) {
        fprintf(stderr, "Error: couldn't get an arena (whatever that is).\n");
        rv = SECFailure;
        goto shutdown;
    }

    rv = SECOID_SetAlgorithmID(arena, &sd.signatureAlgorithm, alg, 0);
    if(rv != SECSuccess) {
        fprintf(stderr, "Error: couldn't set algorithm id.\n");
        SECITEM_FreeItem(&(sd.signature), PR_FALSE);
        PORT_FreeArena(arena, PR_FALSE);
        goto shutdown;
    }

    // Encode results

    SECItem result;
    rv = DER_Encode(arena, &result, CERTSignatureDataTemplate, &sd);
    SECITEM_FreeItem(&(sd.signature), PR_FALSE);
    if(rv != SECSuccess) {
        fprintf(stderr, "Error: couldn't encode result.\n");
        PORT_FreeArena(arena, PR_FALSE);
        goto shutdown;
    }

    char *sign = PL_Base64Encode((const char*)result.data, result.len, NULL);
    PORT_FreeArena(arena, PR_FALSE);
    
    printf("%s\n", sign);


  shutdown:
    if(slot) {
        PK11_FreeSlot(slot);
    }
    if(rv == SECSuccess) {
        return 0;
    } else {
        return 255;
    }
}
