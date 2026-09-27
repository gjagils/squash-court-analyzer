package com.squashanalyzer.android.data

import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * Mirrors the shape of iOS' `SavedBadgeAward` (see ARCHITECTURE.md's Badges
 * section), minus CloudKit-only fields (`cardId`/`awardedBy`/
 * `cloudSystemFields`): Android has no card sharing, so an award is keyed
 * directly to a `PlayerProfile.id`. The primary key is the deterministic
 * "<playerId>:<badge>:<matchId>" triple itself (no SHA-256 needed locally,
 * unlike iOS' `awardId(cardId:badge:matchId:)` which must also be a stable
 * UUID for CloudKit record names).
 */
@Entity(tableName = "badge_awards")
data class BadgeAwardEntity(
    @PrimaryKey val id: String,
    val playerId: String,
    val badge: String, // BadgeKind raw value
    val matchId: String,
    val earnedAt: Long,
    val deletedAt: Long? = null,
)
