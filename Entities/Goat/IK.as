//namespace IK
//{
	class IK_Limb
	{
		Vec2f anchor;
		Vec2f end;
		float length;
		float angle;

		IK_Limb() {}

		void Update(Vec2f Target)
		{
		    float jointAngle0;
		    float jointAngle1;		    

		    Vec2f diff = Target - anchor;
		    float length2 = diff.getLength();

		    // Angle from Joint0 and Target
		    float atan = Maths::ATan2(diff.y, diff.x); //* Maths::Rad2Deg; getAngleDegrees()

		    // Is the target reachable?
		    // If not, we stretch as far as possible
		    //if (length0 + length1 < length2)
		    //{
		    //    float jointAngle0 = atan;
		    //    float jointAngle1 = 0.0f;
		    //}
		    //else
		    {
		        float cosAngle0 = ((length2 * length2) + (length0 * length0) - (length1 * length1)) / (2 * length2 * length0);
		        float angle0 = Maths::ACos(cosAngle0); // * Maths::Rad2Deg;

		        float cosAngle1 = ((length1 * length1) + (length0 * length0) - (length2 * length2)) / (2 * length1 * length0);
		        float angle1 = Maths::ACos(cosAngle1); // * Maths::Rad2Deg;

		        // So they work in Unity reference frame
		        jointAngle0 = atan - angle0;
		        jointAngle1 = 180.0f - angle1;
				//Joint0.RotateByDegrees(jointAngle0);			 
				//Joint1.RotateByDegrees(jointAngle0);
		    }
		    //...
		}

		void Render(Vec2f Target)
		{
			GUI::DrawLine(anchor, end, SColor(255,255,255,255));
		}
	}

    class SimpleIK
    {
        CBlob@ ownerBlob;

        //IK_Limb limb0();
        IK_Limb limb1();
        IK_Limb limb2();
        Vec2f End; 

        Vec2f Target;

        SimpleIK() {}
        SimpleIK(CBlob@ _blob, Vec2f _pos1, float _leng1, Vec2f _pos2, float _leng2) 
        {
        	@ownerBlob = _blob;
        	limb1.anchor = _blob.getPosition();
        	limb1.end = _pos1;
        	limb1.length = _leng1;
        	limb2.anchor = _pos1;
        	limb2.end = _pos2;
        	limb2.length = _leng2;
        }

        void Update()
		{
		    limb1.Update(Target);
		    limb2.Update(Target);
		}

		void Render()
		{
			limb1.Render(Target);
		    limb2.Render(Target);
		}
    }        
//}
/*
class Segment 
{
	f32 angle;
	f32 len;
	Vec2f a;

	Segment(){}
    Segment( f32 _x, f32 _y, f32 _len, int _i) 
    {
        this.angle = 0;
        //if (x instanceof Segment) 
        //{
        //    // create from vector x, with len y
        //    this.sw = map(len, 0, 20, 1, 10);
        //    this.a = x.b.copy();
        //    this.len = y;
        //    this.calculateB();
        //} 
        //else 
        {
            // create new vector
            this.a = Vec2f(_x, _y);
            this.len = _len;
            this.calculateB();
        }
    }

    void followChild() 
    {
    	Segment child(1,2,40,1);
        f32 targetX = child.a.x;
        f32 targetY = child.a.y;
        this.follow(targetX, targetY);
    }

    void follow(f32 tx, f32 ty) {
        Vec2f target = Vec2f(tx, ty);
        Vec2f dir = p5.Vec2f.sub(target, this.a);
        this.angle = dir.heading();
        dir.setMag(this.len);
        dir.mult(-1);
        this.a = p5.Vec2f.add(target, dir);
    }

    void setA(Vec2f pos) {
        this.a = pos.copy();
        this.calculateB();
    }

    void calculateB() {
        f32 dx = this.len * cos(this.angle);
        f32 dy = this.len * sin(this.angle);
        this.b.set(this.a.x + dx, this.a.y + dy);
    }

    void update() {
        this.calculateB();
    }

    void Render() 
    {
        GUI::DrawLine(this.a, this.b, SColor(255,255,255,255));
    }
}

Segment[] tentacles();

Vec2f pos;
Vec2f vel;
Vec2f gravity;

void Setup() 
{
    createCanvas(800, 600);
    pos = Vec2f(0, 0);
    vel = Vec2f(2, 1.3);
    gravity = Vec2f(0, 0.1);
    vel.mult(3);

    f32 da = TWO_PI / 2;
    for (int a = 0; a < TWO_PI; a += da) {
        f32 x = width / 2 + cos(a) * 300;
        f32 y = height / 2 + sin(a) * 300;
        tentacles.push(Tentacle(x, y));
    }
}

void Draw() 
{
    for (int i = 0; i < tentacles.length; i++) {
        int t = tentacles[i];
        t.update();
        t.Render();
    }

    pos.add(vel);
    vel.add(gravity);

    if (pos.x > width || pos.x < 0) {
        vel.x *= -1;
    }

    if (pos.y > height) {
        pos.y = height;
        vel.y *= -1;
        vel.mult(0.95);
    }
}

class Tentacle 
{
    Tentacle(f32 x, f32 y) 
    {
        this.segments = [];
        this.base = Vec2f(x, y);
        this.len = 50;
        this.segments[0] = new Segment(300, 200, this.len, 0);        
        for (int i = 1; i < 5; i++) 
        {
            this.segments[i] = new Segment(this.segments[i - 1], this.len, i);
        }
    }

    void update() {
        int total = this.segments.length;
        int end = this.segments[total - 1];
        end.follow(pos.x, pos.y);
        end.update();

        for (int i = total - 2; i >= 0; i--) 
        {
            this.segments[i].followChild(this.segments[i + 1]);
            this.segments[i].update();
        }

        this.segments[0].setA(this.base);

        for (int i = 1; i < total; i++) 
        {
            this.segments[i].setA(this.segments[i - 1].b);
        }
    }

    void Render() 
    {
        for (int i = 0; i < this.segments.length; i++) 
        {
            this.segments[i].Render();
        }
    }
}