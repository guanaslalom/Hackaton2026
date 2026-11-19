import { LightningElement, api } from 'lwc';
import {
    MISMATCH_DELAY_MS,
    buildDeck,
    canFlip,
    countMatchedPairs,
    flipCard,
    formatTime,
    hideUnmatchedCards,
    isBoardComplete,
    isMatch,
    matchCards,
    shouldTimeOut
} from 'c/memoryGameEngine';

/**
 * Game board: header, card grid, and the flip/match state machine. The server only sees the
 * flip sequence when the game finishes (gamefinished), so no Apex calls happen during play.
 */
export default class MemoryGameBoard extends LightningElement {
    _board;
    deck = [];
    openPositions = [];
    attempts = [];
    isLocked = false;
    isFinished = false;
    elapsedSeconds = 0;
    timerId;
    mismatchTimerId;

    @api
    get board() {
        return this._board;
    }
    set board(value) {
        this.stopTimers();
        this._board = value;
        this.deck = buildDeck(value ? value.cards : []);
        this.openPositions = [];
        this.attempts = [];
        this.isLocked = false;
        this.isFinished = false;
        this.elapsedSeconds = 0;
    }

    get hasBoard() {
        return Boolean(this._board);
    }

    get timerDisplay() {
        return formatTime(this.elapsedSeconds);
    }

    get moveCount() {
        return this.attempts.length;
    }

    get matchedLabel() {
        return `${countMatchedPairs(this.deck)} / ${this._board ? this._board.numberOfPairs : 0}`;
    }

    get cardViews() {
        return this.deck.map((card) => {
            let cardAriaLabel = `Face-down card ${card.position + 1}`;
            if (card.isMatched) {
                cardAriaLabel = `Matched: ${card.label}`;
            } else if (card.isFlipped) {
                cardAriaLabel = card.label;
            }
            return {
                key: `card-${card.position}`,
                position: card.position,
                cardClass: `memory-card${card.isFlipped ? ' is-flipped' : ''}${card.isMatched ? ' is-matched' : ''}`,
                cardAriaLabel,
                symbolText: card.displaySymbol || card.label,
                imageUrl: card.imageUrl,
                disabled: this.isFinished
            };
        });
    }

    disconnectedCallback() {
        this.stopTimers();
    }

    handleCardSelect(event) {
        const position = event.detail.position;
        if (this.isFinished || !canFlip(this.deck, position, this.openPositions, this.isLocked)) {
            return;
        }
        if (this.timerId === undefined) {
            this.timerId = setInterval(() => this.tick(), 1000);
        }

        this.deck = flipCard(this.deck, position);
        this.openPositions = [...this.openPositions, position];
        if (this.openPositions.length < 2) {
            return;
        }

        const [first, second] = this.openPositions;
        this.attempts = [...this.attempts, { first, second }];
        if (isMatch(this.deck, first, second)) {
            this.deck = matchCards(this.deck, first, second);
            this.openPositions = [];
            if (isBoardComplete(this.deck)) {
                this.finish(false);
            }
        } else {
            this.isLocked = true;
            this.mismatchTimerId = setTimeout(() => this.hideMismatch(first, second), MISMATCH_DELAY_MS);
        }
    }

    hideMismatch(first, second) {
        this.deck = hideUnmatchedCards(this.deck, first, second);
        this.openPositions = [];
        this.isLocked = false;
        this.mismatchTimerId = undefined;
    }

    tick() {
        this.elapsedSeconds += 1;
        if (shouldTimeOut(this.elapsedSeconds, this._board.maximumTime)) {
            this.finish(true);
        }
    }

    finish(timedOut) {
        if (this.isFinished) {
            return;
        }
        this.isFinished = true;
        this.stopTimers();
        this.dispatchEvent(
            new CustomEvent('gamefinished', {
                detail: {
                    sessionId: this._board.sessionId,
                    attempts: this.attempts,
                    durationSeconds: this.elapsedSeconds,
                    timedOut
                }
            })
        );
    }

    handleRestart() {
        this.dispatchEvent(new CustomEvent('restart', { detail: { gameId: this._board.gameId } }));
    }

    handleExit() {
        this.dispatchEvent(new CustomEvent('exit', { detail: { sessionId: this._board.sessionId } }));
    }

    stopTimers() {
        if (this.timerId !== undefined) {
            clearInterval(this.timerId);
            this.timerId = undefined;
        }
        if (this.mismatchTimerId !== undefined) {
            clearTimeout(this.mismatchTimerId);
            this.mismatchTimerId = undefined;
        }
    }
}
