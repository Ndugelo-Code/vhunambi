package com.vhunambi.vhunambi_client

import com.ryanheise.audioservice.AudioServiceActivity

// Phase 9 hardware audio bridge: the activity extends AudioServiceActivity so the
// native MediaSession / notification transport can attach to this Flutter engine.
class MainActivity : AudioServiceActivity()
