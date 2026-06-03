#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#ifdef _WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
#pragma comment(lib, "ws2_32.lib")
#define DART_EXPORT __declspec(dllexport)
#else
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <pthread.h>
#define DART_EXPORT
#endif

// Function pointer callbacks to Dart FFI
typedef void (*PeerCallback)(const char* hash, const char* alias, uint32_t seed, float signal);
typedef void (*MessageCallback)(const char* sender_hash, const char* sender_alias, const char* content);

// Global State variables
static char g_alias[64] = {0};
static char g_node_id[33] = {0};
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

static PeerCallback g_peer_cb = NULL;
static MessageCallback g_msg_cb = NULL;

#define UDP_PORT 8099
#define BUFFER_SIZE 1024

// Thread function that periodically broadcasts the presence beacon
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
#ifdef _WIN32
        Sleep(3000); // Wait 3 seconds
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

// Thread function that listens for incoming UDP packets
#ifdef _WIN32
DWORD WINAPI RecvThreadFunc(LPVOID lpParam) {
#else
void* RecvThreadFunc(void* lpParam) {
#endif
    (void)lpParam;
    char buffer[BUFFER_SIZE];
    struct sockaddr_in sender_addr;
    int sender_addr_len = sizeof(sender_addr);

    while (g_running) {
        memset(buffer, 0, BUFFER_SIZE);
        int bytes_received = recvfrom(
            g_recv_socket, 
            buffer, 
            BUFFER_SIZE - 1, 
            0, 
            (struct sockaddr*)&sender_addr, 
            &sender_addr_len
        );

        if (bytes_received > 0 && g_running) {
            buffer[bytes_received] = '\0';
            
            // Check for beacons: YAMILINK_BEACON:alias:seed:node_id
            if (strncmp(buffer, "YAMILINK_BEACON:", 16) == 0) {
                char alias[64] = {0};
                uint32_t seed = 0;
                char node_id[64] = {0};
                
                // Parse beacon fields
                int parsed = sscanf(buffer + 16, "%63[^:]:%u:%63s", alias, &seed, node_id);
                if (parsed == 3 && strcmp(node_id, g_node_id) != 0) {
                    if (g_peer_cb) {
                        // Estimate simple proximity based on network properties or defaults
                        g_peer_cb(node_id, alias, seed, 0.9f);
                    }
                }
            }
            // Check for message room broadcasts: YAMILINK_MSG:sender_id:sender_alias:content
            else if (strncmp(buffer, "YAMILINK_MSG:", 13) == 0) {
                char sender_id[64] = {0};
                char sender_alias[64] = {0};
                char content[512] = {0};

                int parsed = sscanf(buffer + 13, "%63[^:]:%63[^:]:%511[^\n]", sender_id, sender_alias, content);
                if (parsed == 3 && strcmp(sender_id, g_node_id) != 0) {
                    if (g_msg_cb) {
                        g_msg_cb(sender_id, sender_alias, content);
                    }
                }
            }
        }
    }

    return 0;
}

DART_EXPORT int32_t yamilink_init(const char* alias, uint32_t seed) {
    if (g_initialized) return 0;

    strncpy(g_alias, alias, sizeof(g_alias) - 1);
    g_seed = seed;

    // Generate a simple deterministic unique Node ID hash based on alias and seed
    snprintf(g_node_id, sizeof(g_node_id), "node_%u_%u", seed, (uint32_t)strlen(alias));

#ifdef _WIN32
    WSADATA wsaData;
    int result = WSAStartup(MAKEWORD(2, 2), &wsaData);
    if (result != 0) return -1;
#endif

    g_initialized = 1;
    return 0;
}

DART_EXPORT int32_t yamilink_start_discovery(PeerCallback peer_cb, MessageCallback msg_cb) {
    if (!g_initialized || g_running) return -1;

    g_peer_cb = peer_cb;
    g_msg_cb = msg_cb;
    g_running = 1;

    // Set up receiving socket
    g_recv_socket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
#ifdef _WIN32
    if (g_recv_socket == INVALID_SOCKET) {
        WSACleanup();
        return -2;
    }
#else
    if (g_recv_socket < 0) return -2;
#endif

    // Set re-use address option
    int reuse_addr = 1;
    setsockopt(g_recv_socket, SOL_SOCKET, SO_REUSEADDR, (char*)&reuse_addr, sizeof(reuse_addr));

    struct sockaddr_in recv_addr;
    recv_addr.sin_family = AF_INET;
    recv_addr.sin_port = htons(UDP_PORT);
    recv_addr.sin_addr.s_addr = htonl(INADDR_ANY); // Bind to all interfaces

    if (bind(g_recv_socket, (struct sockaddr*)&recv_addr, sizeof(recv_addr)) < 0) {
#ifdef _WIN32
        closesocket(g_recv_socket);
        WSACleanup();
#else
        close(g_recv_socket);
#endif
        return -3;
    }

    // Launch background loops
#ifdef _WIN32
    g_thread_handle = CreateThread(NULL, 0, RecvThreadFunc, NULL, 0, NULL);
    g_beacon_thread = CreateThread(NULL, 0, BeaconThreadFunc, NULL, 0, NULL);
#else
    pthread_create(&g_thread_handle, NULL, RecvThreadFunc, NULL);
    pthread_create(&g_beacon_thread, NULL, BeaconThreadFunc, NULL);
#endif

    return 0;
}

DART_EXPORT int32_t yamilink_send_broadcast(const char* content) {
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

    char payload[1024];
    snprintf(payload, sizeof(payload), "YAMILINK_MSG:%s:%s:%s", g_node_id, g_alias, content);

    int sent = sendto(send_socket, payload, (int)strlen(payload), 0, (struct sockaddr*)&recv_addr, sizeof(recv_addr));

#ifdef _WIN32
    closesocket(send_socket);
#else
    close(send_socket);
#endif

    return sent > 0 ? 0 : -3;
}

DART_EXPORT int32_t yamilink_send_direct(const char* recipient_hash, const char* content) {
    // In MVP broadcast room, direct messaging is routed as standard broadcasts 
    // but carries metadata filters for specific recipient address decryption.
    if (!g_running) return -1;

    char payload[1024];
    // Prefix direct message recipient details
    snprintf(payload, sizeof(payload), "YAMILINK_MSG:%s:%s:[DM_TO:%s]%s", g_node_id, g_alias, recipient_hash, content);

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

    int sent = sendto(send_socket, payload, (int)strlen(payload), 0, (struct sockaddr*)&recv_addr, sizeof(recv_addr));

#ifdef _WIN32
    closesocket(send_socket);
#else
    close(send_socket);
#endif

    return sent > 0 ? 0 : -3;
}

DART_EXPORT int32_t yamilink_stop(void) {
    if (!g_running) return 0;
    g_running = 0;

    // Shutdown sockets to interrupt blocking recvfrom
#ifdef _WIN32
    if (g_recv_socket != INVALID_SOCKET) {
        closesocket(g_recv_socket);
        g_recv_socket = INVALID_SOCKET;
    }
    // Wait for threads to exit
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
