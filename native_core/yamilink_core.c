#include "yamilink_core.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
#pragma comment(lib, "ws2_32.lib")
#else
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <pthread.h>
#endif

// Global State
static char g_alias[64] = {0};
static char g_node_id[65] = {0}; // 64 hex + null
static uint32_t g_seed = 0;
static int g_initialized = 0;
static int g_running = 0;

#ifdef _WIN32
static SOCKET g_recv_socket = INVALID_SOCKET;
static HANDLE g_thread_handle = NULL;
static HANDLE g_beacon_thread = NULL;
#else
static int g_recv_socket = -1;
static pthread_t g_thread_handle;
static pthread_t g_beacon_thread;
#endif

static EventDispatcher g_dispatcher = NULL;

#define UDP_PORT 8099
#define BUFFER_SIZE 4096

// Beacon broadcasting loop
#ifdef _WIN32
DWORD WINAPI BeaconThreadFunc(LPVOID lpParam) {
#else
void* BeaconThreadFunc(void* lpParam) {
#endif
    (void)lpParam;
    
#ifdef _WIN32
    SOCKET send_socket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (send_socket == INVALID_SOCKET) return 0;
    BOOL broadcast_opt = TRUE;
    setsockopt(send_socket, SOL_SOCKET, SO_BROADCAST, (char*)&broadcast_opt, sizeof(broadcast_opt));
#else
    int send_socket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (send_socket < 0) return NULL;
    int broadcast_opt = 1;
    setsockopt(send_socket, SOL_SOCKET, SO_BROADCAST, &broadcast_opt, sizeof(broadcast_opt));
#endif

    struct sockaddr_in recv_addr;
    recv_addr.sin_family = AF_INET;
    recv_addr.sin_port = htons(UDP_PORT);
    recv_addr.sin_addr.s_addr = htonl(INADDR_BROADCAST); // 255.255.255.255

    char beacon_msg[256];
    snprintf(beacon_msg, sizeof(beacon_msg), "YAMILINK_BEACON:%s:%u:%s", g_alias, g_seed, g_node_id);

    while (g_running) {
        sendto(send_socket, beacon_msg, (int)strlen(beacon_msg), 0, (struct sockaddr*)&recv_addr, sizeof(recv_addr));
        
        struct sockaddr_in multi_addr;
        multi_addr.sin_family = AF_INET;
        multi_addr.sin_port = htons(UDP_PORT);
        multi_addr.sin_addr.s_addr = inet_addr("224.0.0.1");
        sendto(send_socket, beacon_msg, (int)strlen(beacon_msg), 0, (struct sockaddr*)&multi_addr, sizeof(multi_addr));
        
#ifdef _WIN32
        Sleep(3000); // 3 seconds
#else
        sleep(3);
#endif
    }

#ifdef _WIN32
    closesocket(send_socket);
    return 0;
#else
    close(send_socket);
    return NULL;
#endif
}

// Receiver loop
#ifdef _WIN32
DWORD WINAPI RecvThreadFunc(LPVOID lpParam) {
#else
void* RecvThreadFunc(void* lpParam) {
#endif
    (void)lpParam;
    uint8_t buffer[BUFFER_SIZE];
    struct sockaddr_in sender_addr;
    int sender_addr_len = sizeof(sender_addr);

    while (g_running) {
        memset(buffer, 0, BUFFER_SIZE);
        int bytes_received = recvfrom(
            g_recv_socket, 
            (char*)buffer, 
            BUFFER_SIZE - 1, 
            0, 
            (struct sockaddr*)&sender_addr, 
            &sender_addr_len
        );

        if (bytes_received > 0 && g_running) {
            // Check if it is a beacon packet: YAMILINK_BEACON:alias:seed:node_id
            if (strncmp((char*)buffer, "YAMILINK_BEACON:", 16) == 0) {
                buffer[bytes_received] = '\0';
                char alias[64] = {0};
                uint32_t seed = 0;
                char node_id[65] = {0};
                
                int parsed = sscanf((char*)buffer + 16, "%63[^:]:%u:%64s", alias, &seed, node_id);
                if (parsed == 3 && strcmp(node_id, g_node_id) != 0) {
                    if (g_dispatcher) {
                        YamiLinkEvent ev = {0};
                        ev.event_type = 0; // NodeDiscovered
                        ev.sender_hash = node_id;
                        ev.sender_alias = alias;
                        ev.avatar_seed = seed;
                        ev.raw_packet = NULL;
                        ev.raw_packet_len = 0;
                        ev.signal_rssi = 0.9f;
                        g_dispatcher(&ev);
                    }
                }
            } else if (bytes_received >= 0 && (size_t)bytes_received >= sizeof(YML2Header)) {
                // Parse Binary Protocol YML2
                YML2Header* header = (YML2Header*)buffer;
                if (header->version == 2) {
                    // Validate packet bounds
                    uint32_t expected_size = sizeof(YML2Header) + header->payload_len + 64; // 64 for signature
                    if (bytes_received >= 0 && (uint32_t)bytes_received >= expected_size) {
                        if (g_dispatcher) {
                            YamiLinkEvent ev = {0};
                            ev.event_type = 1; // PacketReceived
                            ev.sender_hash = "";
                            ev.sender_alias = "";
                            ev.avatar_seed = 0;
                            ev.raw_packet = buffer;
                            ev.raw_packet_len = bytes_received;
                            ev.signal_rssi = 0.9f;
                            g_dispatcher(&ev);
                        }
                    }
                }
            }
        }
    }

    return 0;
}

DART_EXPORT int32_t yamilink_core_start(const char* alias, uint32_t seed, EventDispatcher dispatcher) {
    if (g_running) return 0;

    snprintf(g_alias, sizeof(g_alias), "%s", alias);
    g_seed = seed;
    g_dispatcher = dispatcher;
    
    // We don't have the real pubkey node_id in C unless passed from Dart, 
    // for now we'll just hash the alias/seed or just accept it as parameter in a future update.
    // Actually, beacon logic needs the pubkey node_id.
    // We should update start function to take the node_id.
    // For now, let's just make it generic.
    snprintf(g_node_id, sizeof(g_node_id), "node_%u_%u", seed, (uint32_t)strlen(alias));

#ifdef _WIN32
    WSADATA wsaData;
    int result = WSAStartup(MAKEWORD(2, 2), &wsaData);
    if (result != 0) return -1;
#endif

    g_running = 1;

    g_recv_socket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
#ifdef _WIN32
    if (g_recv_socket == INVALID_SOCKET) {
        WSACleanup();
        g_running = 0;
        return -2;
    }
#else
    if (g_recv_socket < 0) {
        g_running = 0;
        return -2;
    }
#endif

    int reuse_addr = 1;
    setsockopt(g_recv_socket, SOL_SOCKET, SO_REUSEADDR, (char*)&reuse_addr, sizeof(reuse_addr));

    struct sockaddr_in recv_addr;
    recv_addr.sin_family = AF_INET;
    recv_addr.sin_port = htons(UDP_PORT);
    recv_addr.sin_addr.s_addr = htonl(INADDR_ANY);

    if (bind(g_recv_socket, (struct sockaddr*)&recv_addr, sizeof(recv_addr)) < 0) {
#ifdef _WIN32
        closesocket(g_recv_socket);
        WSACleanup();
#else
        close(g_recv_socket);
#endif
        g_running = 0;
        return -3;
    }

#ifdef _WIN32
    g_thread_handle = CreateThread(NULL, 0, RecvThreadFunc, NULL, 0, NULL);
    g_beacon_thread = CreateThread(NULL, 0, BeaconThreadFunc, NULL, 0, NULL);
#else
    pthread_create(&g_thread_handle, NULL, RecvThreadFunc, NULL);
    pthread_create(&g_beacon_thread, NULL, BeaconThreadFunc, NULL);
#endif

    g_initialized = 1;
    return 0;
}

DART_EXPORT int32_t yamilink_core_send(const uint8_t* data, uint32_t length) {
    if (!g_running) return -1;

#ifdef _WIN32
    SOCKET send_socket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (send_socket == INVALID_SOCKET) return -2;
    BOOL broadcast_opt = TRUE;
    setsockopt(send_socket, SOL_SOCKET, SO_BROADCAST, (char*)&broadcast_opt, sizeof(broadcast_opt));
#else
    int send_socket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (send_socket < 0) return -2;
    int broadcast_opt = 1;
    setsockopt(send_socket, SOL_SOCKET, SO_BROADCAST, &broadcast_opt, sizeof(broadcast_opt));
#endif

    struct sockaddr_in recv_addr;
    recv_addr.sin_family = AF_INET;
    recv_addr.sin_port = htons(UDP_PORT);
    recv_addr.sin_addr.s_addr = htonl(INADDR_BROADCAST);

    int sent = sendto(send_socket, (const char*)data, (int)length, 0, (struct sockaddr*)&recv_addr, sizeof(recv_addr));

    struct sockaddr_in multi_addr;
    multi_addr.sin_family = AF_INET;
    multi_addr.sin_port = htons(UDP_PORT);
    multi_addr.sin_addr.s_addr = inet_addr("224.0.0.1");
    sendto(send_socket, (const char*)data, (int)length, 0, (struct sockaddr*)&multi_addr, sizeof(multi_addr));

#ifdef _WIN32
    closesocket(send_socket);
#else
    close(send_socket);
#endif

    return sent > 0 ? 0 : -3;
}

DART_EXPORT int32_t yamilink_core_stop(void) {
    if (!g_running) return 0;
    g_running = 0;

#ifdef _WIN32
    if (g_recv_socket != INVALID_SOCKET) {
        closesocket(g_recv_socket);
        g_recv_socket = INVALID_SOCKET;
    }
    if (g_thread_handle != NULL) {
        WaitForSingleObject(g_thread_handle, 500);
        CloseHandle(g_thread_handle);
        g_thread_handle = NULL;
    }
    if (g_beacon_thread != NULL) {
        WaitForSingleObject(g_beacon_thread, 500);
        CloseHandle(g_beacon_thread);
        g_beacon_thread = NULL;
    }
    WSACleanup();
#else
    if (g_recv_socket >= 0) {
        close(g_recv_socket);
        g_recv_socket = -1;
    }
    pthread_join(g_thread_handle, NULL);
    pthread_join(g_beacon_thread, NULL);
#endif

    g_initialized = 0;
    return 0;
}
