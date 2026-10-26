package
{
	import flash.display.DisplayObject;
	import flash.display.StageQuality;
	import flash.system.System;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.utils.getTimer;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.events.TouchEvent;
	import flash.ui.Keyboard;
	import flash.ui.Multitouch;
	import flash.ui.MultitouchInputMode;
	import flash.utils.Dictionary;
	import flash.utils.getDefinitionByName;

	/**
	 * On-screen LEFT / RIGHT / UP buttons for Home Sheep Home 2.
	 *
	 * Compiled to its own touch.swf. The game loads it at startup, and it sends
	 * ordinary arrow-key events to the stage, so the game logic is untouched.
	 */
	public class TouchControls extends Sprite
	{
		[Embed(source="left.png")]
		private static var LeftArt:Class;
		[Embed(source="right.png")]
		private static var RightArt:Class;
		[Embed(source="up.png")]
		private static var UpArt:Class;

		// ---- tweak these (sizes are fractions of the screen HEIGHT) -------
		/** Button size. 0.13 matches the iOS version. */
		private static const SIZE_FRACTION:Number = 0.13;
		/** Left edge of the LEFT button. */
		private static const LEFT_X:Number = 0.08;
		/** Left edge of the RIGHT button. */
		private static const RIGHT_X:Number = 0.29;
		/** Distance from the right screen edge to the left edge of the UP button. */
		private static const UP_FROM_RIGHT:Number = 0.21;
		/** Gap under the buttons. */
		private static const BOTTOM_MARGIN:Number = 0.03;
		/** Opacity when idle (1 while pressed). */
		private static const IDLE_ALPHA:Number = 0.65;
		/** true = buttons only show while a level is on screen. false = always show. */
		private static const LEVEL_ONLY:Boolean = true;
		/**
		 * false = one KEY_DOWN on press, one KEY_UP on release.
		 * true  = also resend KEY_DOWN every frame while held (keyboard auto-repeat).
		 * Try true only if the sheep take a single step per tap.
		 */
		private static const REPEAT_KEY_DOWN:Boolean = false;
		/**
		 * Rendering quality, applied every frame because the game resets it to HIGH
		 * on each screen change. StageQuality.LOW is fastest, MEDIUM is a good middle,
		 * HIGH is what the game uses by default. Use "" to leave the game alone.
		 */
		private static const FORCE_QUALITY:String = StageQuality.LOW;
		/** true = show a small "fps / memory" readout at the top while in a level. */
		private static const SHOW_FPS:Boolean = false;
		// ------------------------------------------------------------------

		private var leftBtn:Sprite;
		private var rightBtn:Sprite;
		private var upBtn:Sprite;

		private var keyOf:Dictionary = new Dictionary();      // button -> keyCode
		private var held:Dictionary = new Dictionary();       // button -> true while pressed
		private var touchOwner:Dictionary = new Dictionary(); // touchPointID -> button
		private var mouseBtn:Sprite;
		private var useTouch:Boolean;
		private var detectFailures:int = 0;
		private var appClass:Object;
		private var frameCount:int = 0;
		private var fpsText:TextField;
		private var lastTick:int = 0;
		private var fpsFrames:int = 0;

		public function TouchControls()
		{
			if (stage)
			{
				init();
			}
			else
			{
				addEventListener(Event.ADDED_TO_STAGE, init);
			}
		}

		private function init(e:Event = null):void
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);

			useTouch = Multitouch.supportsTouchEvents;
			if (useTouch)
			{
				// Needed so two fingers (e.g. RIGHT + UP) work at the same time.
				Multitouch.inputMode = MultitouchInputMode.TOUCH_POINT;
				stage.addEventListener(TouchEvent.TOUCH_END, onTouchEnd);
			}

			leftBtn = makeButton(new LeftArt(), Keyboard.LEFT);
			rightBtn = makeButton(new RightArt(), Keyboard.RIGHT);
			upBtn = makeButton(new UpArt(), Keyboard.UP);

			if (SHOW_FPS)
			{
				fpsText = new TextField();
				fpsText.mouseEnabled = false;
				fpsText.selectable = false;
				fpsText.defaultTextFormat = new TextFormat("_sans", 30, 0xFF0000, true);
				fpsText.width = 500;
				fpsText.height = 50;
				addChild(fpsText);
				lastTick = getTimer();
			}

			layout();
			stage.addEventListener(Event.RESIZE, layout);
			addEventListener(Event.ENTER_FRAME, onFrame);
			visible = !LEVEL_ONLY;
		}

		private function makeButton(art:DisplayObject, keyCode:uint):Sprite
		{
			var b:Sprite = new Sprite();
			b.addChild(art);
			b.mouseChildren = false;
			b.alpha = IDLE_ALPHA;
			keyOf[b] = keyCode;
			if (useTouch)
			{
				b.addEventListener(TouchEvent.TOUCH_BEGIN, onTouchBegin);
			}
			else
			{
				// Desktop testing (adl): the mouse stands in for a finger.
				b.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
			}
			addChild(b);
			return b;
		}

		private function layout(e:Event = null):void
		{
			var w:Number = stage.stageWidth;
			var h:Number = stage.stageHeight;
			var size:Number = h * SIZE_FRACTION;
			var y:Number = h - size - h * BOTTOM_MARGIN;

			place(leftBtn, h * LEFT_X, y, size);
			place(rightBtn, h * RIGHT_X, y, size);
			place(upBtn, w - h * UP_FROM_RIGHT, y, size);
			if (fpsText != null)
			{
				fpsText.x = w * 0.5 - 250;
				fpsText.y = h * 0.02;
			}
		}

		private function place(b:Sprite, x:Number, y:Number, size:Number):void
		{
			var art:DisplayObject = b.getChildAt(0);
			art.scaleX = 1;
			art.scaleY = 1;
			var k:Number = size / Math.max(art.width, art.height);
			art.scaleX = k;
			art.scaleY = k;
			b.x = x;
			b.y = y;
		}

		// ---- touch --------------------------------------------------------
		private function onTouchBegin(e:TouchEvent):void
		{
			var b:Sprite = e.currentTarget as Sprite;
			touchOwner[e.touchPointID] = b;
			press(b);
		}

		private function onTouchEnd(e:TouchEvent):void
		{
			var b:Sprite = touchOwner[e.touchPointID] as Sprite;
			if (b == null)
			{
				return;
			}
			delete touchOwner[e.touchPointID];
			release(b);
		}

		// ---- mouse (desktop test only) -----------------------------------
		private function onMouseDown(e:MouseEvent):void
		{
			mouseBtn = e.currentTarget as Sprite;
			press(mouseBtn);
			stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
		}

		private function onMouseUp(e:MouseEvent):void
		{
			stage.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp);
			if (mouseBtn != null)
			{
				release(mouseBtn);
				mouseBtn = null;
			}
		}

		// ---- key events ---------------------------------------------------
		private function press(b:Sprite):void
		{
			if (held[b])
			{
				return;
			}
			held[b] = true;
			b.alpha = 1;
			sendKey(KeyboardEvent.KEY_DOWN, keyOf[b]);
		}

		private function release(b:Sprite):void
		{
			if (!held[b])
			{
				return;
			}
			delete held[b];
			b.alpha = IDLE_ALPHA;
			sendKey(KeyboardEvent.KEY_UP, keyOf[b]);
		}

		private function releaseAll():void
		{
			for (var b:Object in held)
			{
				release(b as Sprite);
			}
		}

		private function sendKey(type:String, keyCode:uint):void
		{
			stage.dispatchEvent(new KeyboardEvent(type, true, false, 0, keyCode));
		}

		// ---- per-frame ----------------------------------------------------
		private function onFrame(e:Event):void
		{
			keepOnTop();

			if (fpsText != null)
			{
				fpsFrames++;
				var now:int = getTimer();
				if (now - lastTick >= 1000)
				{
					fpsText.text = Math.round(fpsFrames * 1000 / (now - lastTick)) + " fps   " + Math.round(System.totalMemory / 1048576) + " MB";
					fpsFrames = 0;
					lastTick = now;
				}
			}

			if (FORCE_QUALITY != "" && stage.quality != FORCE_QUALITY)
			{
				stage.quality = FORCE_QUALITY;
			}

			// Checking the game's screen a few times a second is plenty.
			if (frameCount++ % 5 == 0)
			{
				var show:Boolean = shouldShow();
				if (show != visible)
				{
					visible = show;
					if (!show)
					{
						releaseAll(); // never leave a key stuck down when a level ends
					}
				}
			}

			if (REPEAT_KEY_DOWN)
			{
				for (var b:Object in held)
				{
					sendKey(KeyboardEvent.KEY_DOWN, keyOf[b]);
				}
			}
		}

		/**
		 * Asks the game which screen it is on. The game's classes are visible from
		 * here because this SWF is loaded as a child of the game.
		 * If the lookup keeps failing, the buttons just stay visible.
		 */
		private function shouldShow():Boolean
		{
			if (!LEVEL_ONLY || detectFailures >= 30)
			{
				return true;
			}
			try
			{
				if (appClass == null)
				{
					appClass = getDefinitionByName("com.aardman.app.App");
				}
				var app:Object = appClass.inst;
				if (app == null)
				{
					return false; // still on the splash screen
				}
				detectFailures = 0;
				var label:String = String(app.trans.curLabel);
				return label == "game" || label == "reset";
			}
			catch (err:Error)
			{
				detectFailures++;
				return false;
			}
			return true;
		}

		/** The game adds its own screens to the stage later, so keep the buttons above them. */
		private function keepOnTop():void
		{
			var top:DisplayObject = this;
			while (top.parent != null && top.parent != stage)
			{
				top = top.parent;
			}
			if (top.parent == stage && stage.getChildIndex(top) < stage.numChildren - 1)
			{
				stage.setChildIndex(top, stage.numChildren - 1);
			}
		}
	}
}
