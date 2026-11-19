/**
 * Read-only leaderboard for one game. Ranks each player by their best completed score.
 * Runs without sharing so players can see other players' display names and scores;
 * it exposes only the display name, score, duration, and moves.
 *
 * @author Slalom
 */
public without sharing class MemoryLeaderboardService {

    private static final Integer MAX_PLAYERS_SCANNED = 2000;

    /** One ranked player. */
    public class Entry {
        public Integer rank;
        public String displayName;
        public Integer score;
        public Integer durationSeconds;
        public Integer moves;
        public Boolean isCurrentPlayer;
    }

    /** Leaderboard for one game, from the requesting player's point of view. */
    public class Leaderboard {
        public List<Entry> topEntries;
        public Entry myEntry;
        public Integer totalPlayers;
    }

    /**
     * Builds the leaderboard for a game.
     *
     * @param gameId Game__c Id
     * @param contactId Requesting player's Contact (may be null)
     * @param topN Number of top players to return
     * @return The leaderboard
     */
    public static Leaderboard getLeaderboard(Id gameId, Id contactId, Integer topN) {
        List<AggregateResult> bests = [
            SELECT Player__c pid, MAX(Final_Score__c) best
            FROM Game_Session__c
            WHERE Game__c = :gameId AND Status__c = 'Completed' AND Player__c != null
            GROUP BY Player__c
            ORDER BY MAX(Final_Score__c) DESC
            LIMIT :MAX_PLAYERS_SCANNED
        ];

        List<Id> rankedIds = new List<Id>();
        Map<Id, Integer> rankByPlayer = new Map<Id, Integer>();
        Integer previousScore = null;
        Integer previousRank = 0;
        for (Integer i = 0; i < bests.size(); i++) {
            Id playerId = (Id) bests[i].get('pid');
            Integer score = ((Decimal) bests[i].get('best')).intValue();
            Integer rank = (previousScore != null && score == previousScore) ? previousRank : i + 1;
            rankedIds.add(playerId);
            rankByPlayer.put(playerId, rank);
            previousScore = score;
            previousRank = rank;
        }

        Integer topCount = Math.min(Math.max(topN, 0), rankedIds.size());
        List<Id> wanted = new List<Id>();
        for (Integer i = 0; i < topCount; i++) {
            wanted.add(rankedIds[i]);
        }
        if (contactId != null && rankByPlayer.containsKey(contactId) && !wanted.contains(contactId)) {
            wanted.add(contactId);
        }

        Map<Id, Game_Session__c> bestSessionByPlayer = new Map<Id, Game_Session__c>();
        if (!wanted.isEmpty()) {
            for (Game_Session__c session : [
                SELECT Player__c, Final_Score__c, Duration_Seconds__c, Total_Moves__c,
                    Player__r.FirstName, Player__r.LastName
                FROM Game_Session__c
                WHERE Game__c = :gameId AND Status__c = 'Completed' AND Player__c IN :wanted
                ORDER BY Final_Score__c DESC, Duration_Seconds__c ASC
            ]) {
                if (!bestSessionByPlayer.containsKey(session.Player__c)) {
                    bestSessionByPlayer.put(session.Player__c, session);
                }
            }
        }

        Leaderboard board = new Leaderboard();
        board.topEntries = new List<Entry>();
        board.totalPlayers = rankedIds.size();
        for (Integer i = 0; i < topCount; i++) {
            board.topEntries.add(toEntry(bestSessionByPlayer.get(rankedIds[i]), rankByPlayer.get(rankedIds[i]), contactId));
        }
        if (contactId != null && bestSessionByPlayer.containsKey(contactId)) {
            board.myEntry = toEntry(bestSessionByPlayer.get(contactId), rankByPlayer.get(contactId), contactId);
        }
        return board;
    }

    private static Entry toEntry(Game_Session__c session, Integer rank, Id contactId) {
        Entry entry = new Entry();
        entry.rank = rank;
        entry.displayName = displayName(session.Player__r);
        entry.score = session.Final_Score__c == null ? 0 : session.Final_Score__c.intValue();
        entry.durationSeconds = session.Duration_Seconds__c == null ? 0 : session.Duration_Seconds__c.intValue();
        entry.moves = session.Total_Moves__c == null ? 0 : session.Total_Moves__c.intValue();
        entry.isCurrentPlayer = session.Player__c == contactId;
        return entry;
    }

    /**
     * First name plus the last initial, for example "Ada L.".
     */
    private static String displayName(Contact player) {
        String firstName = player.FirstName == null ? '' : player.FirstName.trim();
        String lastInitial = String.isBlank(player.LastName) ? '' : player.LastName.trim().substring(0, 1) + '.';
        return (firstName + ' ' + lastInitial).trim();
    }
}
