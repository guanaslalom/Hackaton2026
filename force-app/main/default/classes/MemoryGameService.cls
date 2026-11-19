/**
 * Server-side rules for the Memory Matching Game: session lifecycle, card layout,
 * replay validation, and scoring. Every query and DML is scoped to the Contact passed in.
 *
 * @author Slalom
 */
public with sharing class MemoryGameService {

    private static final Integer MIN_PAIRS = 2;
    private static final Integer MAX_PAIRS = 18;
    private static final Integer MAX_CLOCK_SKEW_SECONDS = 10;
    private static final Integer MAX_ATTEMPTS = 1000;

    /** Scoring settings copied from a Game__c record. */
    public class ScoringRules {
        public Integer basePoints;
        public Integer movePenalty;
        public Integer timePenalty;
        public Integer intervalSeconds;
        public Integer completionBonus;
    }

    /** Score breakdown returned to the client. */
    public class ScoreBreakdown {
        public Integer baseScore;
        public Integer extraMoves;
        public Integer movePenaltyTotal;
        public Integer intervalsElapsed;
        public Integer timePenaltyTotal;
        public Integer completionBonus;
        public Integer finalScore;
    }

    /** One board position. pairKey lets the client match flips; the other fields render the face. */
    public class BoardCard {
        public Integer position;
        public String pairKey;
        public String label;
        public String imageUrl;
        public String displaySymbol;
    }

    /** A new game board for the client. */
    public class Board {
        public String sessionId;
        public String gameId;
        public String gameName;
        public Integer numberOfPairs;
        public Integer maximumTime;
        public List<BoardCard> cards;
    }

    /** One two-card flip submitted by the client. */
    public class Attempt {
        public Integer first;
        public Integer second;
    }

    /** Result of submitting a finished game. */
    public class SubmitResult {
        public String sessionId;
        public String status;
        public String message;
        public Integer moves;
        public Integer matchedPairs;
        public Integer durationSeconds;
        public ScoreBreakdown score;
    }

    /** Stats for one player on one game. */
    public class PlayerStats {
        public Integer gamesPlayed;
        public Integer gamesCompleted;
        public Integer personalBest;
    }

    /** A card in the shuffled layout, with the card record it displays. */
    private class Slot {
        public String key;
        public Game_Card__c card;
    }

    /**
     * Returns the Contact linked to the running user. Rejects guests and users without a Contact.
     *
     * @return Id of the player's Contact
     */
    public static Id resolveCurrentContactId() {
        if (UserInfo.getUserType() == 'Guest') {
            throw userError('Please log in to play.');
        }
        List<User> users = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (users.isEmpty() || users[0].ContactId == null) {
            throw userError('Your user is not linked to a contact, so game sessions cannot be recorded.');
        }
        return users[0].ContactId;
    }

    /**
     * Calculates the score for a completed game.
     * Extra moves cost movePenalty each, every full interval costs timePenalty, and completion adds the bonus.
     *
     * @param rules Scoring settings from the game
     * @param numberOfPairs Pairs on the board
     * @param moves Number of two-card flips
     * @param durationSeconds Elapsed time in seconds
     * @return The score breakdown, with finalScore floored at 0
     */
    public static ScoreBreakdown calculateScore(ScoringRules rules, Integer numberOfPairs, Integer moves, Integer durationSeconds) {
        ScoreBreakdown breakdown = new ScoreBreakdown();
        breakdown.baseScore = rules.basePoints;
        breakdown.extraMoves = Math.max(0, moves - numberOfPairs);
        breakdown.movePenaltyTotal = breakdown.extraMoves * rules.movePenalty;
        breakdown.intervalsElapsed = rules.intervalSeconds > 0 ? durationSeconds / rules.intervalSeconds : 0;
        breakdown.timePenaltyTotal = breakdown.intervalsElapsed * rules.timePenalty;
        breakdown.completionBonus = rules.completionBonus;
        breakdown.finalScore = Math.max(0, rules.basePoints - breakdown.movePenaltyTotal - breakdown.timePenaltyTotal + rules.completionBonus);
        return breakdown;
    }

    /**
     * Starts a game for a player: picks random valid pairs, shuffles them, stores the layout on the session.
     * Any session still in progress for the same game is abandoned first.
     *
     * @param contactId Player's Contact
     * @param gameId Game__c Id
     * @return The board to render
     */
    public static Board startSession(Id contactId, Id gameId) {
        List<Game__c> games = [
            SELECT Id, Name, Number_of_Pairs__c, Maximum_Time__c, Is_Active__c
            FROM Game__c
            WHERE Id = :gameId
            LIMIT 1
        ];
        if (games.isEmpty() || !games[0].Is_Active__c) {
            throw userError('This game is not available.');
        }
        Game__c game = games[0];
        Integer pairCount = toInt(game.Number_of_Pairs__c, 0);
        if (pairCount < MIN_PAIRS || pairCount > MAX_PAIRS) {
            throw userError('Number of pairs must be between 2 and 18.');
        }

        abandonOpenSessions(contactId, gameId);

        Map<String, List<Game_Card__c>> cardsByKey = groupActiveCards(gameId);
        List<String> validKeys = new List<String>();
        for (String key : cardsByKey.keySet()) {
            if (cardsByKey.get(key).size() == 2) {
                validKeys.add(key);
            }
        }
        if (validKeys.size() < pairCount) {
            throw userError('This game needs at least ' + pairCount + ' complete pairs. Ask an administrator to check the game cards.');
        }

        shuffle(validKeys);
        List<Slot> slots = new List<Slot>();
        for (Integer i = 0; i < pairCount; i++) {
            String key = validKeys[i];
            for (Game_Card__c card : cardsByKey.get(key)) {
                Slot slot = new Slot();
                slot.key = key;
                slot.card = card;
                slots.add(slot);
            }
        }
        shuffle(slots);

        List<String> layout = new List<String>();
        for (Slot slot : slots) {
            layout.add(slot.key);
        }

        Game_Session__c session = new Game_Session__c(
            Game__c = gameId,
            Player__c = contactId,
            Status__c = 'In Progress',
            Start_Date__c = System.now(),
            Total_Moves__c = 0,
            Matched_Pairs__c = 0,
            Final_Score__c = 0,
            Card_Layout__c = JSON.serialize(layout)
        );
        insert session;

        Board board = new Board();
        board.sessionId = session.Id;
        board.gameId = gameId;
        board.gameName = game.Name;
        board.numberOfPairs = pairCount;
        board.maximumTime = toInt(game.Maximum_Time__c, 0);
        board.cards = new List<BoardCard>();
        for (Integer i = 0; i < slots.size(); i++) {
            BoardCard boardCard = new BoardCard();
            boardCard.position = i;
            boardCard.pairKey = slots[i].key;
            boardCard.label = slots[i].card.Name;
            boardCard.imageUrl = slots[i].card.Image_URL__c;
            boardCard.displaySymbol = slots[i].card.Display_Symbol__c;
            board.cards.add(boardCard);
        }
        return board;
    }

    /**
     * Validates a finished game by replaying the player's flips against the stored layout,
     * then records the server-calculated score. Exceeding the time limit abandons the session with score 0.
     *
     * @param contactId Player's Contact
     * @param sessionId Game_Session__c Id
     * @param attemptsJson JSON array of {"first": n, "second": n} flips
     * @param durationSeconds Client-reported elapsed time in seconds
     * @return The submission result
     */
    public static SubmitResult submitSession(Id contactId, Id sessionId, String attemptsJson, Integer durationSeconds) {
        Game_Session__c session = lockOpenSession(contactId, sessionId);
        if (session.Status__c != 'In Progress') {
            throw userError('This game has already been submitted.');
        }
        Game__c game = [
            SELECT Id, Maximum_Time__c, Base_Score__c, Move_Penalty__c, Time_Penalty__c,
                Time_Penalty_Interval_Seconds__c, Completion_Bonus__c
            FROM Game__c
            WHERE Id = :session.Game__c
            LIMIT 1
        ];

        if (durationSeconds == null || durationSeconds < 0) {
            throw userError('Invalid game duration.');
        }
        Integer elapsedSeconds = (Integer) ((System.now().getTime() - session.Start_Date__c.getTime()) / 1000);
        if (durationSeconds > elapsedSeconds + MAX_CLOCK_SKEW_SECONDS) {
            throw userError('Reported duration is longer than the time since the game started.');
        }

        List<Attempt> attempts = parseAttempts(attemptsJson);
        Integer maximumTime = toInt(game.Maximum_Time__c, 0);
        session.Completion_Date__c = System.now();
        session.Duration_Seconds__c = durationSeconds;
        session.Total_Moves__c = attempts.size();

        if (maximumTime > 0 && durationSeconds > maximumTime) {
            session.Status__c = 'Abandoned';
            session.Final_Score__c = 0;
            session.Matched_Pairs__c = 0;
            update session;
            return buildSubmitResult(session, 'Abandoned', 'The time limit was exceeded, so this game scores 0.', null);
        }

        List<String> layout = (List<String>) JSON.deserialize(session.Card_Layout__c, List<String>.class);
        Integer matchedPairs = replayAttempts(layout, attempts);
        if (matchedPairs * 2 != layout.size()) {
            throw userError('Not all pairs have been matched yet.');
        }

        ScoringRules rules = new ScoringRules();
        rules.basePoints = toInt(game.Base_Score__c, 1000);
        rules.movePenalty = toInt(game.Move_Penalty__c, 10);
        rules.timePenalty = toInt(game.Time_Penalty__c, 2);
        rules.intervalSeconds = toInt(game.Time_Penalty_Interval_Seconds__c, 5);
        rules.completionBonus = toInt(game.Completion_Bonus__c, 100);
        ScoreBreakdown breakdown = calculateScore(rules, matchedPairs, attempts.size(), durationSeconds);

        session.Status__c = 'Completed';
        session.Matched_Pairs__c = matchedPairs;
        session.Final_Score__c = breakdown.finalScore;
        update session;
        return buildSubmitResult(session, 'Completed', 'Well played!', breakdown);
    }

    /**
     * Abandons the player's session (used by Restart and Exit). Score is 0. No-op if already finished.
     *
     * @param contactId Player's Contact
     * @param sessionId Game_Session__c Id
     */
    public static void abandonSession(Id contactId, Id sessionId) {
        Game_Session__c session = lockOpenSession(contactId, sessionId);
        if (session.Status__c != 'In Progress') {
            return;
        }
        session.Status__c = 'Abandoned';
        session.Completion_Date__c = System.now();
        session.Final_Score__c = 0;
        update session;
    }

    /**
     * Returns the player's session counts and personal best for one game.
     *
     * @param contactId Player's Contact
     * @param gameId Game__c Id
     * @return Stats for the player
     */
    public static PlayerStats getPlayerStats(Id contactId, Id gameId) {
        PlayerStats stats = new PlayerStats();
        stats.gamesPlayed = 0;
        stats.gamesCompleted = 0;
        stats.personalBest = 0;
        for (AggregateResult row : [
            SELECT Status__c st, COUNT(Id) cnt, MAX(Final_Score__c) best
            FROM Game_Session__c
            WHERE Player__c = :contactId AND Game__c = :gameId AND Status__c != 'In Progress'
            GROUP BY Status__c
        ]) {
            Integer count = (Integer) row.get('cnt');
            stats.gamesPlayed += count;
            if ('Completed'.equals((String) row.get('st'))) {
                stats.gamesCompleted = count;
                stats.personalBest = toInt((Decimal) row.get('best'), 0);
            }
        }
        return stats;
    }

    /**
     * Abandons every in-progress session for this player and game in one statement.
     */
    private static void abandonOpenSessions(Id contactId, Id gameId) {
        List<Game_Session__c> open = [
            SELECT Id, Status__c, Completion_Date__c, Final_Score__c
            FROM Game_Session__c
            WHERE Player__c = :contactId AND Game__c = :gameId AND Status__c = 'In Progress'
        ];
        for (Game_Session__c session : open) {
            session.Status__c = 'Abandoned';
            session.Completion_Date__c = System.now();
            session.Final_Score__c = 0;
        }
        update open;
    }

    /**
     * Loads one session that belongs to the player, locking the row for the duration of the transaction.
     */
    private static Game_Session__c lockOpenSession(Id contactId, Id sessionId) {
        List<Game_Session__c> rows = [
            SELECT Id, Game__c, Status__c, Start_Date__c, Card_Layout__c
            FROM Game_Session__c
            WHERE Id = :sessionId AND Player__c = :contactId
            LIMIT 1
            FOR UPDATE
        ];
        if (rows.isEmpty()) {
            throw userError('Game session not found.');
        }
        return rows[0];
    }

    /**
     * Groups the game's active cards by Pair_Identifier__c in one query.
     */
    private static Map<String, List<Game_Card__c>> groupActiveCards(Id gameId) {
        Map<String, List<Game_Card__c>> cardsByKey = new Map<String, List<Game_Card__c>>();
        for (Game_Card__c card : [
            SELECT Id, Name, Pair_Identifier__c, Image_URL__c, Display_Symbol__c
            FROM Game_Card__c
            WHERE Game__c = :gameId AND Is_Active__c = true AND Pair_Identifier__c != null
            ORDER BY Name
        ]) {
            if (!cardsByKey.containsKey(card.Pair_Identifier__c)) {
                cardsByKey.put(card.Pair_Identifier__c, new List<Game_Card__c>());
            }
            cardsByKey.get(card.Pair_Identifier__c).add(card);
        }
        return cardsByKey;
    }

    /**
     * Replays flips against the layout. A flip of two distinct, unmatched positions with equal keys is a match.
     * Throws on any invalid flip.
     *
     * @return Number of matched pairs
     */
    private static Integer replayAttempts(List<String> layout, List<Attempt> attempts) {
        Set<Integer> matched = new Set<Integer>();
        for (Attempt attempt : attempts) {
            if (attempt == null || attempt.first == null || attempt.second == null) {
                throw userError('Each move must flip two cards.');
            }
            if (attempt.first == attempt.second || !isValidPosition(attempt.first, layout) || !isValidPosition(attempt.second, layout)) {
                throw userError('Invalid card selection.');
            }
            if (matched.contains(attempt.first) || matched.contains(attempt.second)) {
                throw userError('A matched card cannot be flipped again.');
            }
            if (layout[attempt.first] == layout[attempt.second]) {
                matched.add(attempt.first);
                matched.add(attempt.second);
            }
        }
        return matched.size() / 2;
    }

    /**
     * Builds the user-facing error. setMessage keeps getMessage() readable outside Aura context (tests).
     */
    private static AuraHandledException userError(String message) {
        AuraHandledException error = new AuraHandledException(message);
        error.setMessage(message);
        return error;
    }

    private static List<Attempt> parseAttempts(String attemptsJson) {
        if (String.isBlank(attemptsJson)) {
            return new List<Attempt>();
        }
        List<Attempt> attempts = (List<Attempt>) JSON.deserialize(attemptsJson, List<Attempt>.class);
        if (attempts.size() > MAX_ATTEMPTS) {
            throw userError('Too many moves were submitted.');
        }
        return attempts;
    }

    private static Boolean isValidPosition(Integer position, List<String> layout) {
        return position >= 0 && position < layout.size();
    }

    private static SubmitResult buildSubmitResult(Game_Session__c session, String status, String message, ScoreBreakdown breakdown) {
        SubmitResult result = new SubmitResult();
        result.sessionId = session.Id;
        result.status = status;
        result.message = message;
        result.moves = toInt(session.Total_Moves__c, 0);
        result.matchedPairs = toInt(session.Matched_Pairs__c, 0);
        result.durationSeconds = toInt(session.Duration_Seconds__c, 0);
        result.score = breakdown != null ? breakdown : emptyBreakdown();
        return result;
    }

    private static ScoreBreakdown emptyBreakdown() {
        ScoreBreakdown breakdown = new ScoreBreakdown();
        breakdown.baseScore = 0;
        breakdown.extraMoves = 0;
        breakdown.movePenaltyTotal = 0;
        breakdown.intervalsElapsed = 0;
        breakdown.timePenaltyTotal = 0;
        breakdown.completionBonus = 0;
        breakdown.finalScore = 0;
        return breakdown;
    }

    private static Integer toInt(Decimal value, Integer fallback) {
        return value == null ? fallback : value.intValue();
    }

    /** Fisher-Yates shuffle. */
    private static void shuffle(List<String> items) {
        for (Integer i = items.size() - 1; i > 0; i--) {
            Integer j = randomIndex(i + 1);
            String tmp = items[i];
            items[i] = items[j];
            items[j] = tmp;
        }
    }

    /** Fisher-Yates shuffle. */
    private static void shuffle(List<Slot> items) {
        for (Integer i = items.size() - 1; i > 0; i--) {
            Integer j = randomIndex(i + 1);
            Slot tmp = items[i];
            items[i] = items[j];
            items[j] = tmp;
        }
    }

    private static Integer randomIndex(Integer bound) {
        return Math.abs(Math.mod(Crypto.getRandomInteger(), bound));
    }
}
