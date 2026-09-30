package com.squashanalyzer.android.data

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * Same shape as iOS' `SavedBadgeAward` minus its CloudKit bookkeeping, so a
 * card link carries the same awards either way. An award belongs to a card
 * (`players.cardId ?: players.id`, like iOS' `badgeCardId`), not directly to a
 * player, and its id is `AwardValue.awardId(cardId, badge, matchId)` from
 * SquashAnalyzerCore — identical on both platforms, which is what lets two
 * devices merge the same award instead of duplicating it.
 */
@Entity(
    tableName = "badge_awards",
    indices = [Index(value = ["cardId"]), Index(value = ["matchId"])],
)
data class BadgeAwardEntity(
    @PrimaryKey val id: String,
    val cardId: String,
    val badge: String, // BadgeKind raw value
    val matchId: String,
    val earnedAt: Long, // epoch millis
    val opponentName: String,
    val awardedBy: String, // install id of the device that computed it
    val deletedAt: Long? = null, // set once when the user deletes it, never cleared
)
