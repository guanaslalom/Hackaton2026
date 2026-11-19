/**
 * Pure board-state helpers for the Memory Matching Game. No DOM or Apex access, so every
 * function is unit-testable. Each function returns a new deck instead of mutating its input.
 */

export const MISMATCH_DELAY_MS = 1000;

export function formatTime(totalSeconds) {
    const safe = Math.max(0, Math.floor(totalSeconds || 0));
    const minutes = Math.floor(safe / 60);
    const seconds = safe % 60;
    return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
}

export function buildDeck(boardCards) {
    return (boardCards || [])
        .map((card) => ({
            position: card.position,
            pairKey: card.pairKey,
            label: card.label,
            imageUrl: card.imageUrl,
            displaySymbol: card.displaySymbol,
            isFlipped: false,
            isMatched: false
        }))
        .sort((a, b) => a.position - b.position);
}

export function canFlip(deck, position, openPositions, isLocked) {
    if (isLocked || openPositions.length >= 2) {
        return false;
    }
    const card = deck.find((c) => c.position === position);
    return Boolean(card) && !card.isFlipped && !card.isMatched;
}

export function flipCard(deck, position) {
    return deck.map((c) => (c.position === position ? { ...c, isFlipped: true } : c));
}

export function isMatch(deck, firstPosition, secondPosition) {
    if (firstPosition === secondPosition) {
        return false;
    }
    const first = deck.find((c) => c.position === firstPosition);
    const second = deck.find((c) => c.position === secondPosition);
    return Boolean(first && second) && first.pairKey === second.pairKey;
}

export function matchCards(deck, firstPosition, secondPosition) {
    return deck.map((c) =>
        c.position === firstPosition || c.position === secondPosition ? { ...c, isMatched: true } : c
    );
}

export function hideUnmatchedCards(deck, firstPosition, secondPosition) {
    return deck.map((c) =>
        (c.position === firstPosition || c.position === secondPosition) && !c.isMatched
            ? { ...c, isFlipped: false }
            : c
    );
}

export function countMatchedPairs(deck) {
    return Math.floor(deck.filter((c) => c.isMatched).length / 2);
}

export function isBoardComplete(deck) {
    return deck.length > 0 && deck.every((c) => c.isMatched);
}

export function shouldTimeOut(elapsedSeconds, maximumTime) {
    return maximumTime > 0 && elapsedSeconds > maximumTime;
}

export function scoreRows(score) {
    if (!score) {
        return [];
    }
    return [
        { key: 'base', label: 'Base score', value: `${score.baseScore}` },
        { key: 'moves', label: 'Extra moves penalty', value: `-${score.movePenaltyTotal}` },
        { key: 'time', label: 'Time penalty', value: `-${score.timePenaltyTotal}` },
        { key: 'bonus', label: 'Completion bonus', value: `+${score.completionBonus}` },
        { key: 'final', label: 'Final score', value: `${score.finalScore}` }
    ];
}

export function errorMessage(error) {
    return (error && error.body && error.body.message) || (error && error.message) || 'Something went wrong. Please try again.';
}
