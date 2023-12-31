// Goat animations

#include "GoatCommon.as";
#include "RunnerAnimCommon.as";
#include "RunnerCommon.as";
#include "Knocked.as";
#include "PixelOffsets.as"
#include "RunnerTextures.as"
#include "IK.as"

void onInit(CSprite@ this)
{
	addRunnerTextures(this, "goat", "Goat");

	CBlob@ blob = this.getBlob();
	if (blob !is null)
	{
		SimpleIK ik;
		ik.ownerBlob = blob;
		ik.Joint0 = blob.getPosition();
		ik.length0 = 16.0f;
		ik.Joint1 = blob.getPosition()+Vec2f(-6,11);
		ik.length1 = 24.0f;
		blob.set("IKInfo", @ik);
	}
}

void onPlayerInfoChanged(CSprite@ this)
{
	ensureCorrectRunnerTexture(this, "goat", "Goat");
}

void onTick(CSprite@ this)
{
	// store some vars for ease and speed
	CBlob@ blob = this.getBlob();
	Vec2f pos = blob.getPosition();
	Vec2f aimpos;

	GoatInfo@ goat;
	if (!blob.get("goatInfo", @goat))
	{
		return;
	}

	SimpleIK@ ik;
	if (!blob.get("IKInfo", @ik))
	{
		return;
	}
	CControls@ controls = getControls();
	Vec2f mousePos = controls.getMouseWorldPos();
	ik.Joint0 = blob.getPosition();
	ik.Target = mousePos;
	ik.Update();

	const u8 knocked = getKnocked(blob);

	bool shieldState = isShieldState(goat.state);
	bool specialShieldState = isSpecialShieldState(goat.state);
	bool swordState = isSwordState(goat.state);

	bool pressed_a1 = blob.isKeyPressed(key_action1);
	bool pressed_a2 = blob.isKeyPressed(key_action2);

	bool walking = (blob.isKeyPressed(key_left) || blob.isKeyPressed(key_right));

	aimpos = blob.getAimPos();
	bool inair = (!blob.isOnGround() && !blob.isOnLadder());

	Vec2f vel = blob.getVelocity();

	if (blob.hasTag("dead"))
	{
		if (this.animation.name != "dead")
		{
			this.SetAnimation("dead");
		}
		Vec2f oldvel = blob.getOldVelocity();

		//TODO: trigger frame one the first time we server_Die()()
		if (vel.y < -1.0f)
		{
			this.SetFrameIndex(1);
		}
		else if (vel.y > 1.0f)
		{
			this.SetFrameIndex(3);
		}
		else
		{
			this.SetFrameIndex(2);
		}

		return;
	}

	// get the angle of aiming with mouse
	Vec2f vec;
	int direction = blob.getAimDirection(vec);

	// set facing
	bool facingLeft = this.isFacingLeft();
	// animations
	bool ended = this.isAnimationEnded();
	const bool left = blob.isKeyPressed(key_left);
	const bool right = blob.isKeyPressed(key_right);
	const bool up = blob.isKeyPressed(key_up);
	const bool down = blob.isKeyPressed(key_down);

	bool shinydot = false;

	if (knocked > 0)
	{
		if (inair)
		{
			this.SetAnimation("knocked_air");
		}
		else
		{
			this.SetAnimation("knocked");
		}
	}
	else if (blob.hasTag("seated"))
	{
		this.SetAnimation("crouch");
	}
	else if (inair)
	{
		
	}
	else if (walking)
	{
		this.SetAnimation("walk");
	}
	else
	{
		defaultIdleAnim(this, blob, direction);
	}

	//set the head anim
	if (knocked > 0)
	{
		blob.Tag("dead head");
	}
	else if (blob.isKeyPressed(key_use))
	{
		blob.Tag("attack head");
		blob.Untag("dead head");
	}
	else
	{
		blob.Untag("attack head");
		blob.Untag("dead head");
	}

}

void onGib(CSprite@ this)
{
	if (g_kidssafe)
	{
		return;
	}

	CBlob@ blob = this.getBlob();
	Vec2f pos = blob.getPosition();
	Vec2f vel = blob.getVelocity();
	vel.y -= 3.0f;
	f32 hp = Maths::Min(Maths::Abs(blob.getHealth()), 2.0f) + 1.0f;
	const u8 team = blob.getTeamNum();
	CParticle@ Body     = makeGibParticle("Entities/Characters/Goat/GoatGibs.png", pos, vel + getRandomVelocity(90, hp , 80), 0, 0, Vec2f(16, 16), 2.0f, 20, "/BodyGibFall", team);
	CParticle@ Arm      = makeGibParticle("Entities/Characters/Goat/GoatGibs.png", pos, vel + getRandomVelocity(90, hp - 0.2 , 80), 1, 0, Vec2f(16, 16), 2.0f, 20, "/BodyGibFall", team);
	CParticle@ Shield   = makeGibParticle("Entities/Characters/Goat/GoatGibs.png", pos, vel + getRandomVelocity(90, hp , 80), 2, 0, Vec2f(16, 16), 2.0f, 0, "Sounds/material_drop.ogg", team);
	CParticle@ Sword    = makeGibParticle("Entities/Characters/Goat/GoatGibs.png", pos, vel + getRandomVelocity(90, hp + 1 , 80), 3, 0, Vec2f(16, 16), 2.0f, 0, "Sounds/material_drop.ogg", team);
}

// render cursors

void DrawCursorAt(Vec2f position, string& in filename)
{
	position = getMap().getAlignedWorldPos(position);
	if (position == Vec2f_zero) return;
	position = getDriver().getScreenPosFromWorldPos(position - Vec2f(1, 1));
	GUI::DrawIcon(filename, position, getCamera().targetDistance * getDriver().getResolutionScaleFactor());
}

const string cursorTexture = "Entities/Characters/Sprites/TileCursor.png";

void onRender(CSprite@ this)
{
	CBlob@ blob = this.getBlob();
	if (!blob.isMyPlayer())
	{
		return;
	}
	if (getHUD().hasButtons())
	{
		return;
	}

	SimpleIK@ ik;
	if (!blob.get("IKInfo", @ik))
	{
		return;
	}

	ik.Render();

	Vec2f pos = blob.getPosition();

	//GUI::DrawLine(pos, pos+Vec2f(0,12), SColor(255,255,255,255));

	// draw tile cursor

	if (blob.isKeyPressed(key_action1))
	{
		CMap@ map = blob.getMap();
		Vec2f position = blob.getPosition();
		Vec2f cursor_position = blob.getAimPos();
		Vec2f surface_position;
		map.rayCastSolid(position, cursor_position, surface_position);
		Vec2f vector = surface_position - position;
		f32 distance = vector.getLength();
		Tile tile = map.getTile(surface_position);

		if ((map.isTileSolid(tile) || map.isTileGrass(tile.type)) && map.getSectorAtPosition(surface_position, "no build") is null && distance < 16.0f)
		{
			DrawCursorAt(surface_position, cursorTexture);
		}
	}
}
