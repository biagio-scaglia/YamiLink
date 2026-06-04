#ifndef YAMILINK_CORE_H
#define YAMILINK_CORE_H

#include <stdint.h>

#ifdef _WIN32
#define DART_EXPORT __declspec(dllexport)
#else
#define DART_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

// YML2 Protocol Header (Packed for wire)
#pragma pack(push, 1)
typedef struct {
    uint8_t version;         // Always 2 for YML2
    uint8_t type;            // FrameType enum
    char sender_id[64];      // 64-char hex pubkey
    char recipient_id[64];   // 64-char hex pubkey or '*'
    char session_id[32];
    uint32_t message_id;
    uint64_t timestamp;
    uint8_t flags;
    uint8_t hop_count;
    uint16_t payload_len;
} YML2Header;
#pragma pack(pop)

// FFI Struct passed to Dart
typedef struct {
    uint8_t version;
    uint8_t type;
    char sender_id[64];
    char recipient_id[64];
    char session_id[32];
    uint32_t message_id;
    uint64_t timestamp;
    uint8_t flags;
    uint8_t hop_count;
    uint16_t payload_len;
    
    const uint8_t* payload;
    const uint8_t* signature; // Always 64 bytes Ed25519 signature
} YML2PacketFFI;

typedef struct {
    uint8_t event_type;       // 0: NodeDiscovered, 1: PacketReceived, 2: SystemError
    const char* sender_hash;   // Hash key identifier
    const char* sender_alias;  // Node alias
    uint32_t avatar_seed;      // Procedural avatar key
    const YML2PacketFFI* packet; // Parsed packet (for event_type == 1)
    float signal_rssi;         // Signal indicator
} YamiLinkEvent;

typedef void (*EventDispatcher)(const YamiLinkEvent* event);

DART_EXPORT int32_t yamilink_core_start(const char* alias, uint32_t seed, EventDispatcher dispatcher);
DART_EXPORT int32_t yamilink_core_send(const uint8_t* data, uint32_t length);
DART_EXPORT int32_t yamilink_core_stop(void);

#ifdef __cplusplus
}
#endif

#endif // YAMILINK_CORE_H
