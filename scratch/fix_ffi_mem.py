import re
import os

c_file = "c:/Users/biagi/Desktop/yamilink/native_core/yamilink_core.c"
dart_file = "c:/Users/biagi/Desktop/yamilink/lib/ffi_bridge_native.dart"

with open(c_file, "r") as f:
    c_content = f.read()

# Replace NodeDiscovered event creation
node_disc_old = """                        YamiLinkEvent ev = {0};
                        ev.event_type = 0; // NodeDiscovered
                        ev.sender_hash = node_id;
                        ev.sender_alias = alias;
                        ev.avatar_seed = seed;
                        ev.raw_packet = NULL;
                        ev.raw_packet_len = 0;
                        ev.signal_rssi = 0.9f;
                        g_dispatcher(&ev);"""

node_disc_new = """                        YamiLinkEvent* ev = (YamiLinkEvent*)malloc(sizeof(YamiLinkEvent));
                        memset(ev, 0, sizeof(YamiLinkEvent));
                        ev->event_type = 0; // NodeDiscovered
                        
                        char* hash_copy = (char*)malloc(strlen(node_id) + 1);
                        strcpy(hash_copy, node_id);
                        ev->sender_hash = hash_copy;
                        
                        char* alias_copy = (char*)malloc(strlen(alias) + 1);
                        strcpy(alias_copy, alias);
                        ev->sender_alias = alias_copy;
                        
                        ev->avatar_seed = seed;
                        ev->raw_packet = NULL;
                        ev->raw_packet_len = 0;
                        ev->signal_rssi = 0.9f;
                        g_dispatcher(ev);"""

c_content = c_content.replace(node_disc_old, node_disc_new)

# Replace PacketReceived event creation
packet_recv_old = """                            YamiLinkEvent ev = {0};
                            ev.event_type = 1; // PacketReceived
                            ev.sender_hash = "";
                            ev.sender_alias = "";
                            ev.avatar_seed = 0;
                            ev.raw_packet = buffer;
                            ev.raw_packet_len = bytes_received;
                            ev.signal_rssi = 0.9f;
                            g_dispatcher(&ev);"""

packet_recv_new = """                            YamiLinkEvent* ev = (YamiLinkEvent*)malloc(sizeof(YamiLinkEvent));
                            memset(ev, 0, sizeof(YamiLinkEvent));
                            ev->event_type = 1; // PacketReceived
                            ev->sender_hash = NULL;
                            ev->sender_alias = NULL;
                            ev->avatar_seed = 0;
                            
                            uint8_t* p = (uint8_t*)malloc(bytes_received);
                            memcpy(p, buffer, bytes_received);
                            ev->raw_packet = p;
                            ev->raw_packet_len = bytes_received;
                            ev->signal_rssi = 0.9f;
                            g_dispatcher(ev);"""

c_content = c_content.replace(packet_recv_old, packet_recv_new)

# Add yamilink_core_free_event
free_event = """

DART_EXPORT void yamilink_core_free_event(YamiLinkEvent* ev) {
    if (ev) {
        if (ev->raw_packet) free((void*)ev->raw_packet);
        if (ev->sender_hash) free((void*)ev->sender_hash);
        if (ev->sender_alias) free((void*)ev->sender_alias);
        free(ev);
    }
}
"""
c_content += free_event

with open(c_file, "w") as f:
    f.write(c_content)

print("C fixed")

with open(dart_file, "r") as f:
    dart_content = f.read()

# Add free definition
free_def = """
typedef CFreeEventFunc = Void Function(Pointer<YamiLinkEvent> event);
typedef DartFreeEventFunc = void Function(Pointer<YamiLinkEvent> event);
"""
dart_content = dart_content.replace("typedef CSendFunc =", free_def + "\ntypedef CSendFunc =")

# Add free binding
free_bind = """
  late final DartStartFunc _startFunc;
  late final DartFreeEventFunc _freeEventFunc;
"""
dart_content = dart_content.replace("late final DartStartFunc _startFunc;", free_bind)

free_lookup = """
      _startFunc = _lib.lookup<NativeFunction<CStartFunc>>('yamilink_core_start').asFunction();
      
      try {
        _freeEventFunc = _lib.lookup<NativeFunction<CFreeEventFunc>>('yamilink_core_free_event').asFunction();
      } catch (_) {
        // fallback if not found
      }
"""
dart_content = dart_content.replace("_startFunc = _lib.lookup<NativeFunction<CStartFunc>>('yamilink_core_start').asFunction();", free_lookup)


# Call free after reading
dart_call = """
      _eventController.add(YamiLinkEventData(
        type: type,
        senderHash: hash,
        senderAlias: senderAlias,
        seed: avatarSeed,
        signalRssi: signal,
        packetBytes: packetBytes,
      ));

      try {
        _freeEventFunc(eventPtr);
      } catch (_) {}
    });
"""
dart_content = dart_content.replace("""      _eventController.add(YamiLinkEventData(
        type: type,
        senderHash: hash,
        senderAlias: senderAlias,
        seed: avatarSeed,
        signalRssi: signal,
        packetBytes: packetBytes,
      ));
    });""", dart_call)

with open(dart_file, "w") as f:
    f.write(dart_content)

print("Dart fixed")
