package com.squashanalyzer.android.backup

import com.squashanalyzer.android.team.PhotoScaler
import skip.foundation.Data
import squash.analyzer.core.AccountAvatarSource

/** The avatar of the player account (4.0): the system photo picker, made a 512 px square JPEG like a player photo */
class AndroidAvatarSource(private val files: ActivityPlayerFiles) : AccountAvatarSource {
    override suspend fun pickAvatar(): Data? {
        val picked = files.pickPhoto() ?: return null
        val scaled = PhotoScaler.squareJpeg(picked.platformValue) ?: return null
        return Data(platformValue = scaled)
    }
}
