/**
 * Lightning entry points for the Memory Matching Game. Maps requests to MemoryGameService and
 * MemoryLeaderboardService; contains no scoring logic.
 *
 * @author Slalom
 */
public with sharing class MemoryGameController {

    private static final Integer DEFAULT_LEADERBOARD_SIZE = 10;
    private static final Integer MAX_LEADERBOARD_SIZE = 50;

    /**
     * Returns the active games for the portal.
     *
     * @return Active Game__c records
     */
    @AuraEnabled(cacheable=true)
    public static List<Game__c> getActiveGames() {
        return [
            SELECT Id, Name, Description__c, Number_of_Pairs__c, Maximum_Time__c
            FROM Game__c
            WHERE Is_Active__c = true
            ORDER BY Name
        ];
    }

    /**
     * Starts a new game for the current player.
     *
     * @param gameId Game__c Id
     * @return The board to render, as JSON. Returned as a string because the Board object reached the client empty.
     */
    @AuraEnabled
    public static String startSession(Id gameId) {
        return JSON.serialize(MemoryGameService.startSession(MemoryGameService.resolveCurrentContactId(), gameId));
    }

    /**
     * Submits a finished game for server-side validation and scoring.
     *
     * @param sessionId Game_Session__c Id
     * @param attemptsJson JSON array of {"first": n, "second": n} flips
     * @param durationSeconds Elapsed time in seconds
          * @return The submission result, as JSON (see startSession for why this is a string)
     */
    @AuraEnabled
    public static String submitSession(Id sessionId, String attemptsJson, Integer durationSeconds) {
        return JSON.serialize(MemoryGameService.submitSession(MemoryGameService.resolveCurrentContactId(), sessionId, attemptsJson, durationSeconds));
    }

    /**
     * Abandons an in-progress game (Restart or Exit). No-op if the game is already finished.
     *
     * @param sessionId Game_Session__c Id
     */
    @AuraEnabled
    public static void abandonSession(Id sessionId) {
        MemoryGameService.abandonSession(MemoryGameService.resolveCurrentContactId(), sessionId);
    }

    /**
     * Returns the current player's stats for one game.
     *
     * @param gameId Game__c Id
     * @return Stats for the player, as JSON (see startSession for why this is a string)
     */
    @AuraEnabled
    public static String getPlayerStats(Id gameId) {
        return JSON.serialize(MemoryGameService.getPlayerStats(MemoryGameService.resolveCurrentContactId(), gameId));
    }

    /**
     * Returns the leaderboard for one game, including the current player's entry.
     *
     * @param gameId Game__c Id
     * @param topN Number of top players to return (1–50, default 10)
     * @return The leaderboard, as JSON (see startSession for why this is a string)
     */
    @AuraEnabled
    public static String getLeaderboard(Id gameId, Integer topN) {
        Integer size = topN == null ? DEFAULT_LEADERBOARD_SIZE : Math.min(Math.max(topN, 1), MAX_LEADERBOARD_SIZE);
        return JSON.serialize(MemoryLeaderboardService.getLeaderboard(gameId, MemoryGameService.resolveCurrentContactId(), size));
    }
}
