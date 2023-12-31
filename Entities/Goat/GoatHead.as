// generic character head script

// TODO: fix double includes properly, added the following line temporarily to fix include issues
#include "PaletteSwap.as"
#include "PixelOffsets.as"
#include "RunnerTextures.as"

const s32 NUM_HEADFRAMES = 4;
const s32 NUM_UNIQUEHEADS = 0;
const int FRAMES_WIDTH = 1 * NUM_HEADFRAMES;

int getHeadFrame(CBlob@ blob, int headIndex, bool default_pack)
{
	if(headIndex < NUM_UNIQUEHEADS)
	{
		return headIndex * NUM_HEADFRAMES;
	}

	//special heads logic for default heads pack
	if((headIndex == 255 || headIndex == NUM_UNIQUEHEADS))
	{
		{
			// default
			headIndex = NUM_UNIQUEHEADS;
		}		
	}

	return (((headIndex - NUM_UNIQUEHEADS / 2) * 2) +
	        (blob.getSexNum() == 0 ? 0 : 1)) * NUM_HEADFRAMES;
}

void onPlayerInfoChanged(CSprite@ this)
{
	LoadHead(this, this.getBlob().getHeadNum());
}

CSpriteLayer@ LoadHead(CSprite@ this, int headIndex)
{
	this.RemoveSpriteLayer("head");
	// add head
	CSpriteLayer@ head = this.addSpriteLayer("head", "Entities/Goat/GoatHeads.png", 32, 32, 0, 0);
	CBlob@ blob = this.getBlob();

	// set defaults
	headIndex = headIndex % 256; // DLC heads
	s32 headFrame = getHeadFrame(blob, headIndex, true);

	blob.set_s32("head index", headFrame);
	if (head !is null)
	{
		Animation@ anim = head.addAnimation("default", 0, false);
		anim.AddFrame(headFrame);
		anim.AddFrame(headFrame + 1);
		anim.AddFrame(headFrame + 2);
		head.SetAnimation(anim);

		head.SetFacingLeft(blob.isFacingLeft());
	}
	return head;
}

void onGib(CSprite@ this)
{
	if (g_kidssafe)
	{
		return;
	}

	CBlob@ blob = this.getBlob();
	if (blob !is null && blob.getName() != "bed")
	{
		int frame = blob.get_s32("head index");
		int framex = frame % FRAMES_WIDTH;
		int framey = frame / FRAMES_WIDTH;

		Vec2f pos = blob.getPosition();
		Vec2f vel = blob.getVelocity();
		f32 hp = Maths::Min(Maths::Abs(blob.getHealth()), 2.0f) + 1.5;
	//	makeGibParticle(getHeadTexture(blob.getHeadNum()),
	//	                pos, vel + getRandomVelocity(90, hp , 30),
	//	                framex, framey, Vec2f(16, 16),
	//	                2.0f, 20, "/BodyGibFall", blob.getTeamNum());
	}
}

void onTick(CSprite@ this)
{
	CBlob@ blob = this.getBlob();

	ScriptData@ script = this.getCurrentScript();
	if (script is null)
		return;

	if (blob.getShape().isStatic())
	{
		script.tickFrequency = 60;
	}
	else
	{
		script.tickFrequency = 1;
	}


	// head animations
	CSpriteLayer@ head = this.getSpriteLayer("head");

	// load head when player is set or it is AI
	if (head is null && (blob.getPlayer() !is null || (blob.getBrain() !is null && blob.getBrain().isActive()) || blob.getTickSinceCreated() > 3))
	{
		@head = LoadHead(this, blob.getHeadNum());
	}

	if (head !is null)
	{
		Vec2f offset;

		// pixeloffset from script
		// set the head offset and Z value according to the pink/yellow pixels
		int layer = 0;
		Vec2f head_offset = getHeadOffset(blob, -1, layer);

		// behind, in front or not drawn
		if (layer == 0)
		{
			head.SetVisible(false);
		}
		else
		{
			head.SetVisible(this.isVisible());
			head.SetRelativeZ(layer * 0.25f);
		}

		offset = head_offset;

		// set the proper offset
		Vec2f headoffset(this.getFrameWidth() / 2, -this.getFrameHeight() / 2);
		headoffset += this.getOffset();
		headoffset += Vec2f(-offset.x, offset.y);
		headoffset += Vec2f(-6, -4);

		head.SetOffset(headoffset);

		if (blob.hasTag("dead") || blob.hasTag("dead head"))
		{
			head.animation.frame = 2;

			// sparkle blood if cut throat
			if (getNet().isClient() && getGameTime() % 2 == 0 && blob.hasTag("cutthroat"))
			{
				Vec2f vel = getRandomVelocity(90.0f, 1.3f * 0.1f * XORRandom(40), 2.0f);
				ParticleBlood(blob.getPosition() + Vec2f(this.isFacingLeft() ? headoffset.x : -headoffset.x, headoffset.y), vel, SColor(255, 126, 0, 0));
				if (XORRandom(100) == 0)
					blob.Untag("cutthroat");
			}
		}
		else if (blob.hasTag("attack head"))
		{
			head.animation.frame = 1;
		}
		else
		{
			head.animation.frame = 0;
		}

		//////  Angle the head  //////

		Vec2f pos = blob.getPosition();
		f32 angle = (blob.getAimPos() -pos).Angle();
		f32 headangle = -angle;

		if (this.isFacingLeft())
		{
			headangle = 180.0f - angle;
		}

		while (headangle > 180.0f)
		{
			headangle -= 360.0f;
		}

		while (headangle < -180.0f)
		{
			headangle += 360.0f;
		} 
		Vec2f around(8,8);
		f32 sign = (this.isFacingLeft() ? 1.0f : -1.0f);
		setHeadValues(head, true, headangle, 0.1f, "default", Vec2f(-8 * sign, 8), headoffset);
	}
}

void setHeadValues(CSpriteLayer@ head, bool visible, f32 angle, f32 relativeZ, string anim, Vec2f around, Vec2f offset)
{
	if (head !is null)
	{
		if (!head.isAnimation(anim))
		{
			head.SetAnimation(anim);
		}

		head.SetOffset(offset);
		head.ResetTransform();
		head.SetRelativeZ(relativeZ);
		head.RotateBy(angle, around);		
	}
}