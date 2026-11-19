import { LightningElement, api } from 'lwc';
import { formatTime, scoreRows } from 'c/memoryGameEngine';

/**
 * Result screen shown after a submitted game. Scores come from the server; this component only
 * formats them.
 */
export default class MemoryGameComplete extends LightningElement {
    @api result;
    @api previousBest = null;

    get isCompleted() {
        return Boolean(this.result) && this.result.status === 'Completed';
    }

    get isAbandoned() {
        return Boolean(this.result) && this.result.status === 'Abandoned';
    }

    get newBest() {
        return this.isCompleted && (this.previousBest === null || this.result.score.finalScore > this.previousBest);
    }

    get durationDisplay() {
        return formatTime(this.result ? this.result.durationSeconds : 0);
    }

    get finalScoreDisplay() {
        return this.isCompleted ? `${this.result.score.finalScore}` : '0';
    }

    get scoreBreakdown() {
        return scoreRows(this.isCompleted ? this.result.score : null);
    }

    handlePlayAgain() {
        this.dispatchEvent(new CustomEvent('playagain'));
    }

    handleHome() {
        this.dispatchEvent(new CustomEvent('home'));
    }
}
