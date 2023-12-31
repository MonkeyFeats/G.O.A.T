// Goat logic

#include "GoatCommon.as";
#include "RunnerCommon.as";
#include "Hitters.as";
#include "ShieldCommon.as";
#include "Knocked.as"
#include "Help.as";
#include "Requirements.as"


//attacks limited to the one time per-actor before reset.

void goat_actorlimit_setup(CBlob@ this)
{
	u16[] networkIDs;
	this.set("LimitedActors", networkIDs);
}

bool goat_has_hit_actor(CBlob@ this, CBlob@ actor)
{
	u16[]@ networkIDs;
	this.get("LimitedActors", @networkIDs);
	return networkIDs.find(actor.getNetworkID()) >= 0;
}

u32 goat_hit_actor_count(CBlob@ this)
{
	u16[]@ networkIDs;
	this.get("LimitedActors", @networkIDs);
	return networkIDs.length;
}

void goat_add_actor_limit(CBlob@ this, CBlob@ actor)
{
	this.push("LimitedActors", actor.getNetworkID());
}

void goat_clear_actor_limits(CBlob@ this)
{
	this.clear("LimitedActors");
}

void onInit(CBlob@ this)
{
	GoatInfo goat;

	goat.state = GoatStates::normal;
	goat.swordTimer = 0;
	goat.shieldTimer = 0;
	goat.slideTime = 0;
	goat.doubleslash = false;
	goat.shield_down = getGameTime();
	goat.tileDestructionLimiter = 0;

	this.set("goatInfo", @goat);

	this.set_f32("gib health", -1.5f);
	addShieldVars(this, SHIELD_BLOCK_ANGLE, 2.0f, 5.0f);
	goat_actorlimit_setup(this);
	this.getShape().SetRotationsAllowed(false);
	this.getShape().getConsts().net_threshold_multiplier = 0.5f;
	this.Tag("player");
	this.Tag("flesh");
	this.set_u8("Peronality", XORRandom(9));

	this.getCurrentScript().removeIfTag = "dead";

}

void onSetPlayer(CBlob@ this, CPlayer@ player)
{
	if (player !is null)
	{
		player.SetScoreboardVars("ScoreboardIcons.png", 3, Vec2f(16, 16));
	}
}


void onTick(CBlob@ this)
{
	u8 knocked = getKnocked(this);

	if (this.isInInventory())
		return;

	//goat logic stuff
	//get the vars to turn various other scripts on/off
	RunnerMoveVars@ moveVars;
	if (!this.get("moveVars", @moveVars))
	{
		return;
	}

	GoatInfo@ goat;
	if (!this.get("goatInfo", @goat))
	{
		return;
	}

	Vec2f pos = this.getPosition();
	Vec2f vel = this.getVelocity();
	Vec2f aimpos = this.getAimPos();
	const bool inair = (!this.isOnGround() && !this.isOnLadder());

	Vec2f vec;

	const int direction = this.getAimDirection(vec);
	const f32 side = (this.isFacingLeft() ? 1.0f : -1.0f);

	bool shieldState = isShieldState(goat.state);
	bool specialShieldState = isSpecialShieldState(goat.state);
	bool swordState = isSwordState(goat.state);
	bool pressed_a1 = this.isKeyPressed(key_action1);
	bool pressed_a2 = this.isKeyPressed(key_action2);
	bool walking = (this.isKeyPressed(key_left) || this.isKeyPressed(key_right));

	const bool myplayer = this.isMyPlayer();

	CMap@ map = this.getMap();
	Vec2f surface_position;
	map.rayCastSolid(pos, pos+Vec2f(0,12), surface_position);
	Tile tile = map.getTile(surface_position);

	if (map.isTileSolid(tile))
	{
		//this.AddForce(Vec2f(0, -1*this.getMass()*0.45));

		//this.setPosition(pos+Vec2f(0,-12));
	}
	if (this.isKeyJustPressed(key_use))
	{
		if (getNet().isClient())
		{
			u8 personality = this.get_u8("Peronality");
			//string type = //(XORRandom(10) == 0 ? "/GoatScream" : "/GoatNormal");
			//Sound::Play(type+personality, pos, myplayer ? 1.3f : 0.7f);
			Sound::Play("/GoatScream"+XORRandom(10), pos, myplayer ? 1.3f : 0.7f);
		}
	}

	//with the code about menus and myplayer you can slash-cancel;
	//we'll see if goats dmging stuff while in menus is a real issue and go from there
	if (knocked > 0)// || myplayer && getHUD().hasMenus())
	{
		goat.state = GoatStates::normal; //cancel any attacks or shielding
		goat.swordTimer = 0;
		goat.shieldTimer = 0;
		goat.slideTime = 0;
		goat.doubleslash = false;

		pressed_a1 = false;
		pressed_a2 = false;
		walking = false;

	}
	else if (!pressed_a1 && !swordState &&
	         (pressed_a2 || (specialShieldState)))
	{
	//	moveVars.jumpFactor *= 0.5f;
	//	moveVars.walkFactor *= 0.9f;
		goat.swordTimer = 0;

		if (!canRaiseShield(this))
		{
			if (goat.state != GoatStates::normal)
			{
				goat.shield_down = getGameTime() + 40;
			}

			goat.state = GoatStates::normal;

			if (pressed_a2 && ((goat.shield_down - getGameTime()) <= 0))
			{
				resetShieldKnockdown(this);   //re-put up the shield
			}
		}
		else
		{
			bool forcedrop = (vel.y > Maths::Max(Maths::Abs(vel.x), 2.0f) &&
			                  moveVars.fallCount > GoatVars::glide_down_time);

			if (pressed_a2 && inair && !this.isInWater())
			{
				if (direction == -1 && !forcedrop && !getMap().isInWater(pos + Vec2f(0, 16)) && !moveVars.wallsliding)
				{
					goat.state = GoatStates::shieldgliding;
					goat.shieldTimer = 1;
				}
				else if (forcedrop || direction == 1)
				{
					goat.state = GoatStates::shielddropping;
					goat.shieldTimer = 5;
					goat.slideTime = 0;
				}
				else //remove this for partial locking in mid air
				{
					goat.state = GoatStates::shielding;
				}
			}

			if (goat.state == GoatStates::shieldgliding && !this.isInWater() && !forcedrop)
			{
				moveVars.stoppingFactor *= 0.5f;

				f32 glide_amount = 1.0f - (moveVars.fallCount / f32(GoatVars::glide_down_time * 2));

				if (vel.y > -1.0f)
				{
					this.AddForce(Vec2f(0, -20.0f * glide_amount));
				}

				if (!inair || !pressed_a2)
				{
					goat.state = GoatStates::shielding;
				}
			}
			else if (goat.state == GoatStates::shielddropping)
			{
				if (this.isInWater())
				{
					if (vel.y > 1.5f && Maths::Abs(vel.x) * 3 > Maths::Abs(vel.y))
					{
						vel.y = Maths::Max(-Maths::Abs(vel.y) + 1.0f, -8.0);
						this.setVelocity(vel);
					}
					else
					{
						goat.state = GoatStates::shielding;
					}
				}

				// shield sliding and end of slide
				if ((!inair && this.getShape().vellen < 1.0f) || !pressed_a2)
				{
					goat.state = GoatStates::shielding;
				}
				else
				{
					// faster sliding
					if (!inair)
					{
						goat.slideTime++;
						if (goat.slideTime > 0)
						{
							if (goat.slideTime == 5)
							{
								this.getSprite().PlayRandomSound("/Scrape");
							}

							f32 factor = Maths::Max(1.0f, 2.2f / Maths::Sqrt(goat.slideTime));
							moveVars.walkFactor *= factor;

							//  printf("goat.slideTime = " + goat.slideTime  );
							if (goat.slideTime > 30)
							{
								moveVars.walkFactor *= 0.75f;
								if (goat.slideTime > 45)
								{
									goat.state = GoatStates::shielding;
								}
							}
							else if (XORRandom(3) == 0)
							{
								Vec2f velr = getRandomVelocity(!this.isFacingLeft() ? 70 : 110, 4.3f, 40.0f);
								velr.y = -Maths::Abs(velr.y) + Maths::Abs(velr.x) / 3.0f - 2.0f - float(XORRandom(100)) / 100.0f;
								ParticlePixel(pos, velr, SColor(255, 255, 255, 0), true);
							}
						}
					}
					else if (vel.y > 1.05f)
					{
						goat.slideTime = 0;
						//printf("vel.y  " + vel.y  );
					}
				}
			}
			else
			{
				goat.state = GoatStates::shielding;
				goat.shieldTimer = 2;
			}
		}
	}
	else if ((pressed_a1 || swordState) && !moveVars.wallsliding)   //no attacking during a slide
	{
		if (getNet().isClient())
		{
			if (goat.swordTimer == GoatVars::slash_charge_level2)
			{
				Sound::Play("AnimeSword.ogg", pos, myplayer ? 1.3f : 0.7f);
			}
			else if (goat.swordTimer == GoatVars::slash_charge)
			{
				Sound::Play("SwordSheath.ogg", pos, myplayer ? 1.3f : 0.7f);
			}
		}

		if (goat.swordTimer >= GoatVars::slash_charge_limit)
		{
			Sound::Play("/Stun", pos, 1.0f, this.getSexNum() == 0 ? 1.0f : 2.0f);
			SetKnocked(this, 15);
		}

		bool strong = (goat.swordTimer > GoatVars::slash_charge_level2);
		moveVars.jumpFactor *= (strong ? 0.6f : 0.8f);
		moveVars.walkFactor *= (strong ? 0.8f : 0.9f);
		goat.shieldTimer = 0;

		if (!inair)
		{
			this.AddForce(Vec2f(vel.x * -5.0, 0.0f));   //horizontal slowing force (prevents SANICS)
		}

		if (goat.state == GoatStates::normal ||
		        this.isKeyJustPressed(key_action1) &&
		        (!inMiddleOfAttack(goat.state) || shieldState))
		{
			goat.state = GoatStates::sword_drawn;
			goat.swordTimer = 0;
		}

		if (goat.state == GoatStates::sword_drawn && getNet().isServer())
		{
			goat_clear_actor_limits(this);
		}

		//responding to releases/noaction
		s32 delta = goat.swordTimer;
		if (goat.swordTimer < 128)
			goat.swordTimer++;

		if (goat.state == GoatStates::sword_drawn && !pressed_a1 &&
		        !this.isKeyJustReleased(key_action1) && delta > GoatVars::resheath_time)
		{
			goat.state = GoatStates::normal;
		}
		else if (this.isKeyJustReleased(key_action1) && goat.state == GoatStates::sword_drawn)
		{
			goat.swordTimer = 0;

			if (delta < GoatVars::slash_charge)
			{
				if (direction == -1)
				{
					goat.state = GoatStates::sword_cut_up;
				}
				else if (direction == 0)
				{
					if (aimpos.y < pos.y)
					{
						goat.state = GoatStates::sword_cut_mid;
					}
					else
					{
						goat.state = GoatStates::sword_cut_mid_down;
					}
				}
				else
				{
					goat.state = GoatStates::sword_cut_down;
				}
			}
			else if (delta < GoatVars::slash_charge_level2)
			{
				goat.state = GoatStates::sword_power;
				Vec2f aiming_direction = vel;
				aiming_direction.y *= 2;
				aiming_direction.Normalize();
				goat.slash_direction = aiming_direction;
			}
			else if (delta < GoatVars::slash_charge_limit)
			{
				goat.state = GoatStates::sword_power_super;
				Vec2f aiming_direction = vel;
				aiming_direction.y *= 2;
				aiming_direction.Normalize();
				goat.slash_direction = aiming_direction;
			}
			else
			{
				//knock?
			}
		}
		else if (goat.state >= GoatStates::sword_cut_mid &&
		         goat.state <= GoatStates::sword_cut_down) // cut state
		{
			if (delta == DELTA_BEGIN_ATTACK)
			{
				Sound::Play("/SwordSlash", this.getPosition());
			}

			if (delta > DELTA_BEGIN_ATTACK && delta < DELTA_END_ATTACK)
			{
				f32 attackarc = 90.0f;
				f32 attackAngle = getCutAngle(this, goat.state);

				if (goat.state == GoatStates::sword_cut_down)
				{
					attackarc *= 0.9f;
				}

				DoAttack(this, 1.0f, attackAngle, attackarc, Hitters::sword, delta, goat);
			}
			else if (delta >= 9)
			{
				goat.swordTimer = 0;
				goat.state = GoatStates::sword_drawn;
			}
		}
		else if (goat.state == GoatStates::sword_power ||
		         goat.state == GoatStates::sword_power_super)
		{
			//setting double
			if (goat.state == GoatStates::sword_power_super &&
			        this.isKeyJustPressed(key_action1))
			{
				goat.doubleslash = true;
			}

			//attacking + noises
			if (delta == 2)
			{
				Sound::Play("/ArgLong", this.getPosition());
				Sound::Play("/SwordSlash", this.getPosition());
			}
			else if (delta > DELTA_BEGIN_ATTACK && delta < 10)
			{
				DoAttack(this, 2.0f, -(vec.Angle()), 120.0f, Hitters::sword, delta, goat);
			}
			else if (delta >= GoatVars::slash_time ||
			         (goat.doubleslash && delta >= GoatVars::double_slash_time))
			{
				goat.swordTimer = 0;

				if (goat.doubleslash)
				{
					goat_clear_actor_limits(this);
					goat.doubleslash = false;
					goat.state = GoatStates::sword_power;
				}
				else
				{
					goat.state = GoatStates::sword_drawn;
				}
			}
		}

		//special slash movement

		if ((goat.state == GoatStates::sword_power ||
		        goat.state == GoatStates::sword_power_super) &&
		        delta < GoatVars::slash_move_time)
		{

			if (Maths::Abs(vel.x) < GoatVars::slash_move_max_speed &&
			        vel.y > -GoatVars::slash_move_max_speed)
			{
				Vec2f slash_vel =  goat.slash_direction * this.getMass() * 0.5f;
				this.AddForce(slash_vel);
			}
		}

		moveVars.canVault = false;

	}
	else if (this.isKeyJustReleased(key_action2) || this.isKeyJustReleased(key_action1) || this.get_u32("goat_timer") <= getGameTime())
	{
		goat.state = GoatStates::normal;
	}

	if (myplayer)
	{
		// space

		if (this.isKeyJustPressed(key_action3))
		{
			//Spring
		}
	}

	//setting the shield direction properly
	if (shieldState)
	{
		int horiz = this.isFacingLeft() ? -1 : 1;
		setShieldEnabled(this, true);

		setShieldAngle(this, SHIELD_BLOCK_ANGLE);

		if (specialShieldState)
		{
			if (goat.state == GoatStates::shieldgliding)
			{
				setShieldDirection(this, Vec2f(0, -1));
				setShieldAngle(this, SHIELD_BLOCK_ANGLE_GLIDING);
			}
			else //shield dropping
			{
				setShieldDirection(this, Vec2f(horiz, 2));
				setShieldAngle(this, SHIELD_BLOCK_ANGLE_SLIDING);
			}
		}
		else if (walking)
		{
			if (direction == 0) //forward
			{
				setShieldDirection(this, Vec2f(horiz, 0));
			}
			else if (direction == 1)   //down
			{
				setShieldDirection(this, Vec2f(horiz, 3));
			}
			else
			{
				setShieldDirection(this, Vec2f(horiz, -3));
			}
		}
		else
		{
			if (direction == 0)   //forward
			{
				setShieldDirection(this, Vec2f(horiz, 0));
			}
			else if (direction == 1)   //down
			{
				setShieldDirection(this, Vec2f(horiz, 3));
			}
			else //up
			{
				if (vec.y < -0.97)
				{
					setShieldDirection(this, Vec2f(0, -1));
				}
				else
				{
					setShieldDirection(this, Vec2f(horiz, -3));
				}
			}
		}

		// shield up = collideable

		if ((goat.state == GoatStates::shielding && direction == -1) ||
		        goat.state == GoatStates::shieldgliding)
		{
			if (!this.hasTag("shieldplatform"))
			{
				this.getShape().checkCollisionsAgain = true;
				this.Tag("shieldplatform");
			}
		}
		else
		{
			if (this.hasTag("shieldplatform"))
			{
				this.getShape().checkCollisionsAgain = true;
				this.Untag("shieldplatform");
			}
		}
	}
	else
	{
		setShieldEnabled(this, false);

		if (this.hasTag("shieldplatform"))
		{
			this.getShape().checkCollisionsAgain = true;
			this.Untag("shieldplatform");
		}
	}

	if (!swordState && getNet().isServer())
	{
		goat_clear_actor_limits(this);
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{

}

/////////////////////////////////////////////////

bool isJab(f32 damage)
{
	return damage < 1.5f;
}

void DoAttack(CBlob@ this, f32 damage, f32 aimangle, f32 arcdegrees, u8 type, int deltaInt, GoatInfo@ info)
{
	if (!getNet().isServer())
	{
		return;
	}

	if (aimangle < 0.0f)
	{
		aimangle += 360.0f;
	}

	Vec2f blobPos = this.getPosition();
	Vec2f vel = this.getVelocity();
	Vec2f thinghy(1, 0);
	thinghy.RotateBy(aimangle);
	Vec2f pos = blobPos - thinghy * 6.0f + vel + Vec2f(0, -2);
	vel.Normalize();

	f32 attack_distance = Maths::Min(DEFAULT_ATTACK_DISTANCE + Maths::Max(0.0f, 1.75f * this.getShape().vellen * (vel * thinghy)), MAX_ATTACK_DISTANCE);

	f32 radius = this.getRadius();
	CMap@ map = this.getMap();
	bool dontHitMore = false;
	bool dontHitMoreMap = false;
	const bool jab = isJab(damage);

	//get the actual aim angle
	f32 exact_aimangle = (this.getAimPos() - blobPos).Angle();

	// this gathers HitInfo objects which contain blob or tile hit information
	HitInfo@[] hitInfos;
	if (map.getHitInfosFromArc(pos, aimangle, arcdegrees, radius + attack_distance, this, @hitInfos))
	{
		//HitInfo objects are sorted, first come closest hits
		for (uint i = 0; i < hitInfos.length; i++)
		{
			HitInfo@ hi = hitInfos[i];
			CBlob@ b = hi.blob;
			if (b !is null && !dontHitMore) // blob
			{
				if (b.hasTag("ignore sword")) continue;

				//big things block attacks
				const bool large = b.hasTag("blocks sword") && !b.isAttached() && b.isCollidable();

				if (!canHit(this, b))
				{
					// no TK
					if (large)
						dontHitMore = true;

					continue;
				}

				if (goat_has_hit_actor(this, b))
				{
					if (large)
						dontHitMore = true;

					continue;
				}

				goat_add_actor_limit(this, b);
				if (!dontHitMore)
				{
					Vec2f velocity = b.getPosition() - pos;
					this.server_Hit(b, hi.hitpos, velocity, damage, type, true);  // server_Hit() is server-side only

					// end hitting if we hit something solid, don't if its flesh
					if (large)
					{
						dontHitMore = true;
					}
				}
			}
			else  // hitmap
				if (!dontHitMoreMap && (deltaInt == DELTA_BEGIN_ATTACK + 1))
				{
					bool ground = map.isTileGround(hi.tile);
					bool dirt_stone = map.isTileStone(hi.tile);
					bool gold = map.isTileGold(hi.tile);
					bool wood = map.isTileWood(hi.tile);
					if (ground || wood || dirt_stone || gold)
					{
						Vec2f tpos = map.getTileWorldPosition(hi.tileOffset) + Vec2f(4, 4);
						Vec2f offset = (tpos - blobPos);
						f32 tileangle = offset.Angle();
						f32 dif = Maths::Abs(exact_aimangle - tileangle);
						if (dif > 180)
							dif -= 360;
						if (dif < -180)
							dif += 360;

						dif = Maths::Abs(dif);
						//print("dif: "+dif);

						if (dif < 20.0f)
						{
							//detect corner

							int check_x = -(offset.x > 0 ? -1 : 1);
							int check_y = -(offset.y > 0 ? -1 : 1);
							if (map.isTileSolid(hi.hitpos - Vec2f(map.tilesize * check_x, 0)) &&
							        map.isTileSolid(hi.hitpos - Vec2f(0, map.tilesize * check_y)))
								continue;

							bool canhit = true; //default true if not jab
							if (jab) //fake damage
							{
								info.tileDestructionLimiter++;
								canhit = ((info.tileDestructionLimiter % ((wood || dirt_stone) ? 3 : 2)) == 0);
							}
							else //reset fake dmg for next time
							{
								info.tileDestructionLimiter = 0;
							}

							//dont dig through no build zones
							canhit = canhit && map.getSectorAtPosition(tpos, "no build") is null;

							dontHitMoreMap = true;
							if (canhit)
							{
								map.server_DestroyTile(hi.hitpos, 0.1f, this);
							}
						}
					}
				}
		}
	}

	// destroy grass

//	if (((aimangle >= 0.0f && aimangle <= 180.0f) || damage > 1.0f) &&    // aiming down or slash
//	        (deltaInt == DELTA_BEGIN_ATTACK + 1)) // hit only once
//	{
//		f32 tilesize = map.tilesize;
//		int steps = Maths::Ceil(2 * radius / tilesize);
//		int sign = this.isFacingLeft() ? -1 : 1;
//
//		for (int y = 0; y < steps; y++)
//			for (int x = 0; x < steps; x++)
//			{
//				Vec2f tilepos = blobPos + Vec2f(x * tilesize * sign, y * tilesize);
//				TileType tile = map.getTile(tilepos).type;
//
//				if (map.isTileGrass(tile))
//				{
//					map.server_DestroyTile(tilepos, damage, this);
//
//					if (damage <= 1.0f)
//					{
//						return;
//					}
//				}
//			}
//	}
}

bool isSliding(GoatInfo@ goat)
{
	return (goat.slideTime > 0 && goat.slideTime < 800);
}

// shieldbash

void onCollision(CBlob@ this, CBlob@ blob, bool solid, Vec2f normal, Vec2f point1)
{
	//return if we didn't collide or if it's teamie
	if (blob is null || !solid || this.getTeamNum() == blob.getTeamNum())
	{
		return;
	}

	const bool onground = this.isOnGround();
	if (this.getShape().vellen > SHIELD_KNOCK_VELOCITY || onground)
	{
		GoatInfo@ goat;
		if (!this.get("goatInfo", @goat))
		{
			return;
		}

		//printf("goat.stat " + goat.state );
		if (goat.state == GoatStates::shielddropping &&
		        (!onground || isSliding(goat)) &&
		        (blob.getShape() !is null && !blob.getShape().isStatic()) &&
		        getKnocked(blob) == 0)
		{
			Vec2f pos = this.getPosition();
			Vec2f vel = this.getOldVelocity();
			vel.Normalize();

			//printf("nor " + vel * normal );
			if (vel * normal < 0.0f && goat_hit_actor_count(this) == 0) //only bash one thing per tick
			{
				ShieldVars@ shieldVars = getShieldVars(this);
				//printf("shi " + shieldVars.direction * normal );
				if (shieldVars.direction * normal < 0.0f)
				{
					goat_add_actor_limit(this, blob);
					this.server_Hit(blob, pos, vel, 0.0f, Hitters::shield);

					Vec2f force = Vec2f(shieldVars.direction.x * this.getMass(), -this.getMass()) * 3.0f;

					blob.AddForce(force);
					this.AddForce(Vec2f(-force.x, force.y));
				}
			}
		}
	}
}


//a little push forward

void pushForward(CBlob@ this, f32 normalForce, f32 pushingForce, f32 verticalForce)
{
	f32 facing_sign = this.isFacingLeft() ? -1.0f : 1.0f ;
	bool pushing_in_facing_direction =
	    (facing_sign < 0.0f && this.isKeyPressed(key_left)) ||
	    (facing_sign > 0.0f && this.isKeyPressed(key_right));
	f32 force = normalForce;

	if (pushing_in_facing_direction)
	{
		force = pushingForce;
	}

	this.AddForce(Vec2f(force * facing_sign , verticalForce));
}


void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	GoatInfo@ goat;
	if (!this.get("goatInfo", @goat))
	{
		return;
	}

	if (customData == Hitters::sword &&
	        ( //is a jab - note we dont have the dmg in here at the moment :/
	            goat.state == GoatStates::sword_cut_mid ||
	            goat.state == GoatStates::sword_cut_mid_down ||
	            goat.state == GoatStates::sword_cut_up ||
	            goat.state == GoatStates::sword_cut_down
	        )
	        && blockAttack(hitBlob, velocity, 0.0f))
	{
		this.getSprite().PlaySound("/Stun", 1.0f, this.getSexNum() == 0 ? 1.0f : 2.0f);
		SetKnocked(this, 30);
	}

	if (customData == Hitters::shield)
	{
		SetKnocked(hitBlob, 20);
		this.getSprite().PlaySound("/Stun", 1.0f, this.getSexNum() == 0 ? 1.0f : 2.0f);
	}
}

// Blame Fuzzle.
bool canHit(CBlob@ this, CBlob@ b)
{

	if (b.hasTag("invincible"))
		return false;

	// Don't hit temp blobs and items carried by teammates.
	if (b.isAttached())
	{

		CBlob@ carrier = b.getCarriedBlob();

		if (carrier !is null)
			if (carrier.hasTag("player")
			        && (this.getTeamNum() == carrier.getTeamNum() || b.hasTag("temp blob")))
				return false;

	}

	if (b.hasTag("dead"))
		return true;

	return b.getTeamNum() != this.getTeamNum();

}
