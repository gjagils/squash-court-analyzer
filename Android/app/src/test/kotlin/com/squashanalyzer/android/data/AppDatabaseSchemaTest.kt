package com.squashanalyzer.android.data

import androidx.room.testing.MigrationTestHelper
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.io.File

/**
 * The exported schema (`schemas/<version>.json`, committed) is what a future
 * migration is tested against with `MigrationTestHelper` (B17). These tests
 * keep that possible:
 *
 * - the helper can build a database from the exported schema of the current version;
 * - there is a schema file for the current version (a version bump without
 *   committing the new JSON would leave the next migration untestable).
 *
 * That the entities still match the committed JSON is checked by CI: the build
 * rewrites `schemas/` and `git diff --exit-code Android/app/schemas` must be empty.
 *
 * For each new version: commit its JSON, and test the step with
 * `helper.createDatabase(name, old)` + `runMigrationsAndValidate(name, new, true, MIGRATION_x_y)`;
 * the older steps (1 to 9) have SQL-based tests because no JSON was exported for them.
 */
@RunWith(RobolectricTestRunner::class)
class AppDatabaseSchemaTest {
    @get:Rule
    val helper = MigrationTestHelper(InstrumentationRegistry.getInstrumentation(), AppDatabase::class.java)

    private val currentVersion = 9

    @Test fun thereIsAnExportedSchemaForTheCurrentVersion() {
        val schemas = File("schemas/com.squashanalyzer.android.data.AppDatabase")
        assertTrue("schemas/.../$currentVersion.json missing: commit the exported schema", File(schemas, "$currentVersion.json").exists())
    }

    @Test fun aDatabaseCanBeBuiltFromTheExportedSchemaAndOpensWithoutMigrating() {
        helper.createDatabase("schema-guard.db", currentVersion).close()
        helper.runMigrationsAndValidate("schema-guard.db", currentVersion, true).close()
    }
}
