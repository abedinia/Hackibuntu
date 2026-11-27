// Draws falling code over the lock screen's blurred wallpaper. The rest of the
// look is in stylesheet.css, which GNOME loads and unloads with the extension.
//
// This runs only while the screen is locked and never touches the password
// prompt: the rain is a non-reactive layer behind it.
import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import Pango from 'gi://Pango';
import PangoCairo from 'gi://PangoCairo';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

const GLYPHS = [...'ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ0123456789:.=*+-<>'];
const CELL_W = 18;
const CELL_H = 20;
const FRAME_MS = 80;

const randomInt = n => Math.floor(Math.random() * n);
const randomGlyph = () => GLYPHS[randomInt(GLYPHS.length)];

function newDrop(rows) {
    // start above the screen so the columns do not fall in step
    return {head: -randomInt(rows), length: 6 + randomInt(18), speed: 0.35 + Math.random() * 0.65};
}

class Rain {
    constructor(monitor, scale) {
        this._scale = scale;
        this._columns = Math.ceil(monitor.width / scale / CELL_W);
        this._rows = Math.ceil(monitor.height / scale / CELL_H);
        this._drops = Array.from({length: this._columns}, () => {
            const drop = newDrop(this._rows);
            drop.head = randomInt(this._rows * 2) - this._rows; // some already on screen
            return drop;
        });
        this._cells = Array.from({length: this._columns * this._rows}, randomGlyph);

        this.actor = new St.DrawingArea({
            x: monitor.x,
            y: monitor.y,
            width: monitor.width,
            height: monitor.height,
            reactive: false,
        });
        this.actor.connect('repaint', area => this._draw(area));
    }

    step() {
        for (let i = 0; i < this._columns; i++) {
            const drop = this._drops[i];
            drop.head += drop.speed;
            if (drop.head - drop.length > this._rows)
                this._drops[i] = newDrop(this._rows);
        }
        // a few characters flicker
        for (let i = 0; i < this._columns; i++)
            this._cells[randomInt(this._cells.length)] = randomGlyph();
        this.actor.queue_repaint();
    }

    _draw(area) {
        const cr = area.get_context();
        const layout = PangoCairo.create_layout(cr);
        layout.set_font_description(Pango.FontDescription.from_string('monospace 11'));
        cr.scale(this._scale, this._scale);

        // dim what is behind, so the clock and prompt stay readable
        cr.setSourceRGBA(0, 0.02, 0, 0.78);
        cr.paint();

        this._drops.forEach((drop, column) => {
            const head = Math.floor(drop.head);
            for (let i = 0; i < drop.length; i++) {
                const row = head - i;
                if (row < 0 || row >= this._rows)
                    continue;
                if (i === 0)
                    cr.setSourceRGBA(0.85, 1, 0.88, 0.9);
                else
                    cr.setSourceRGBA(0, 1, 0.25, 0.6 * (1 - i / drop.length));
                layout.set_text(this._cells[row * this._columns + column], -1);
                cr.moveTo(column * CELL_W, row * CELL_H);
                PangoCairo.show_layout(cr, layout);
            }
        });
        cr.$dispose();
    }
}

export default class HackerLockExtension extends Extension {
    enable() {
        this._rains = [];
        this._layer = null;
        Main.layoutManager.connectObject('monitors-changed', () => this._build(), this);
        this._build();
        this._timer = GLib.timeout_add(GLib.PRIORITY_DEFAULT, FRAME_MS, () => {
            // nothing to draw while the monitor is blanked
            if (this._layer?.mapped)
                this._rains.forEach(rain => rain.step());
            return GLib.SOURCE_CONTINUE;
        });
    }

    // This extension declares the unlock-dialog session mode because the lock
    // screen is the only thing it changes. disable() removes all of it.
    disable() {
        GLib.source_remove(this._timer);
        this._timer = null;
        Main.layoutManager.disconnectObject(this);
        this._clear();
    }

    _build() {
        this._clear();
        const dialog = Main.screenShield?._dialog;
        if (!dialog?._backgroundGroup)
            return;

        const scale = St.ThemeContext.get_for_stage(global.stage).scale_factor;
        this._layer = new Clutter.Actor({reactive: false});
        this._rains = Main.layoutManager.monitors.map(monitor => new Rain(monitor, scale));
        this._rains.forEach(rain => this._layer.add_child(rain.actor));
        // above the wallpaper, below the clock and the password prompt
        dialog.insert_child_above(this._layer, dialog._backgroundGroup);
        this._layer.connect('destroy', () => {
            this._layer = null;
            this._rains = [];
        });
    }

    _clear() {
        this._layer?.destroy();
        this._layer = null;
        this._rains = [];
    }
}
