//
//  PlanetAssView.mm
//  PlanetAss
//
// thanks in no small part to 
// http://developer.apple.com/mac/library/documentation/Cocoa/Conceptual/ObjectiveC/Articles/ocCPlusPlus.html#//apple_ref/doc/uid/TP30001163-CH10-SW1
// http://cocoadevcentral.com/articles/000089.php
//
//  Created by Brian Hammond on 6/18/10.
//  Copyright (c) 2010, YoMamy. All rights reserved.
//

#import <ScreenSaver/ScreenSaver.h>
#import <OpenGL/gl.h>
#import <OpenGL/glu.h>
#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

#include <stdio.h>
#include <stdlib.h>

#define LAME ( 256 * 0 + 128 * 1 + 64 * 0 + 32 * 0 )

class Point3 {
	private:
		float x,y,z, distance;
	public:
		Point3() {
			this->x = this->y = this->z = 0;
			this->distance = 0;
		}
		Point3( float x,float y,float z ) {
			this->x = x;
			this->y = y;
			this->z = z;
			this->distance = x * x + y * y + z * z;
		}
		Point3( Point3 &that ) {
			this->copy( that );
			this->distance = x * x + y * y + z * z;
		}

		Point3 &copy( Point3 &that ) {
			return this->copy( that.x, that.y, that.z );
		}

		Point3 &copy( float x,float y,float z ) {
			this->x = x;
			this->y = y;
			this->z = z;
			this->dist();
			return *this;
		}

		void scale( float f ) {
			this->x *= f;
			this->y *= f;
			this->z *= f;
			this->dist();
		}

		void print( FILE *bs ) {
			fprintf( bs, "ptz:%f,%f,%f\n", x, y, z );
		}

		void add( Point3 &that ) {
			this->x += that.x;
			this->y += that.y;
			this->z += that.z;
			this->dist();
		}

		void minus( Point3 &that ) {
			this->x -= that.x;
			this->y -= that.y;
			this->z -= that.z;
			this->dist();
		}

		float dot( Point3 &that ) {
			return this->x * that.x + this->y * that.y + this->z * that.z;
		}
		
		float dist() {
			return this->distance = sqrt( this->dot( *this ) );
		}

		float getDist() {
			return this->distance;
		}
		
		void vert() {
			glVertex3f( this->x , this->y , this->z );
		}

		void normalize() {
			float length = this->length();
			if ( 0 == length ) {
				this->distance = 0;
			} else {
				this->x /= length;
				this->y /= length;
				this->z /= length;
				this->distance = 1;
			}
		}

		float length() {
			return this->getDist();
		}

		void cross( Point3 &a, Point3 &b ) {
			// "xyzzy"
			this->x = (a.y * b.z) - (a.z * b.y);
			this->y = (a.z * b.x) - (a.x * b.z);
			this->z = (a.x * b.y) - (a.y * b.x);
		}

		void normal() {
			glNormal3f( this->x, this->y, this->z );
		}
};

class Spheroid {
	private:
		Point3 points[ LAME ][ LAME ];
		FILE *bs;
	public:
		Spheroid( float radius_ = 1.0 ) {
			this->bs = NULL;
			for ( int i = 0 ; i < LAME ; i++ ) {
				float ratio = i / ( float ) ( LAME - 1 ); // from 0 to 1
				ratio = ratio * 2 - 1; // between -1 and +1

				float y = ratio;
				float radius = sqrt( 1 - y * y );

				for ( int j = 0 ; j < LAME ; j++ ) {
					float angle = ( 44.0 / 7.0 ) * ( j / ( float ) ( LAME - 1 ) );
					this->points[ i ][ j ].copy(
						  radius * cos( angle ) * radius_
						, radius * sin( angle ) * radius_
						, y * radius_
					);
				}
			}
		}

		void draw( int madness = 0 ) {
			this->sphereMe( madness );
		}

		void sphereMe( int madness ) {
			float sum = 0;
			int add = 1;
			int underwater = 0;
			float d;
			for ( int i = 0 ; i < LAME ; i++ ) {
				if ( i == LAME - 1 ) add = -1; // don't wrap around poles
				for ( int j = 0 ; j < LAME ; j++ ) {
					this->vert( i + 0,   j + 0, madness );
					this->vert( i + 0,   j + 1, madness );
					this->vert( i + add, j + 0, madness );

					this->vert( i + 0,   j + 1, madness );
					this->vert( i + add, j + 1, madness );
					this->vert( i + add, j + 0, madness );
				
					d = this->points[ i ][ j ].getDist();	
					sum += d;
					if ( d < 0 ) underwater++;
				}
			}

			if ( 0 == madness ) {
				float avg = sum / LAME / LAME;
				if ( avg < 0.8 ) {
					this->scale( 1.1 / avg );
					this->smooth();
					fprintf( bs, "enbiggen: %f (ittle bitty)\n", avg );
				}
				if ( underwater > LAME * LAME * 0.5 ) {
					this->scale( 1.05 );
					fprintf( bs, "enbiggen: %d (underwater)\n", underwater );
				}
			}
		}

		float vert( int i, int j, int madness ) {
			float d = 0;
			
			Point3 &point = iGetUrPoint( i, j );

			switch( madness ) {
				case 0: d = this->distColor( point ); break; // planet
				case 1: glColor3f( 1, 0, 0 ); break; // shit knows
				case 2: glColor4f( 0, 0, 1, 0.5 ); break; // water
			   	case 3: glColor4f( 1, 1, 1, 0.2 ); break; // atmosphere
				case 4: glColor3f( 0.6,0.6,0.3); break; // moon
			} 

			if ( 0 == madness ) {
				Point3 a( iGetUrPoint( i + 1, j ) );
				Point3 b( iGetUrPoint( i, j + 1 ) );
				a.minus( point );
				b.minus( point );

				Point3 cross;
				cross.cross( a, b );
				cross.normalize();

				Point3 nu( point );
				nu.normalize();
				cross.scale( 0.4 );
				nu.scale( 0.6 );
				nu.add( cross );
				nu.normal();
			} else {
				Point3 nu( point );
				nu.normalize();
				nu.normal();
			}

			point.vert();

			return d;
		}

		float distColor( Point3 &point ) {
			float d = point.getDist(); 

			if ( 0 ); 
			else if ( d < 0.99 ) glColor3f( 0.80, 0.80, 1.00 ); // submerged
			else if ( d < 1.03 ) glColor3f( 0.55, 0.27, 0.07 ); // dirt
			else if ( d < 1.10 ) glColor3f( 0.13, 0.54, 0.13 ); // grass
			else if ( d < 1.25 ) glColor3f( 0.41, 0.46, 0.52 ); // stone
			else glColor3f( 1, 1, 1 ); //snow

			return d;
		}

		Point3 &iGetUrPoint( int i, int j ) {
			i = i % LAME;
			j = j % LAME;
			while ( i < 0 ) i += LAME;
			while ( j < 0 ) j += LAME;
			return points[ i ][ j ];
		}

		void upsAndDowns( int i, int j, float d ) {
			upsAndDowns( i, j, d, -1, -1 );
		}

		float rand() {
			return random() / ( float ) RAND_MAX;
		}

		void upsAndDowns( int i, int j, float d, int bi, int bj ) {
			if ( 0.1 > fabs( d ) ) {
				//fprintf( bs, "bail: %d,%d +%f == %f\n", i, j, d, fabs( d ) );
				return;
			}

			float express = 0.01;
			float fall_off = 0.2;

			express = 0.01;
			fall_off = 0.7;

			Point3 &point = iGetUrPoint( i, j );
			Point3 b4( point );
			point.scale( 1 + d * express );

			float dist = point.dot( point );
			if ( dist < 0.25 ) {
				point.copy( b4 );
				//fprintf( bs, "smoochies\n" );
			}

			for ( int q = i - 1 ; q < i + 2 ; q++ ) {
				for ( int p = j - 1 ; p < j + 2 ; p++ ) {
					if ( i == q && j == p ) continue;
					if ( bi == q && bj == p ) continue;
					upsAndDowns( q, p, d * fall_off * ( 0.9 + 0.2 * rand() ) , i, j );
				}
			}
		}

		void smooth() {
			float distance[ LAME ][ LAME ];
			float tmp[ LAME ][ LAME ];
			for ( int i = 0 ; i < LAME ; i++ ) {
				for ( int j = 0 ; j < LAME ; j++ ) {
					distance[ i ][ j ] = this->points[ i ][ j ].getDist();
					tmp[ i ][ j ] = 0;
				}
			}

			int count;
			int a;
			int b;

			for ( int i = 0 ; i < LAME ; i++ ) {
				for ( int j = 0 ; j < LAME ; j++ ) {
					count = 0;
					for ( int q = i - 1 ; q < i + 2 ; q++ ) {
						a = q;
						if ( a < 0 ) a += LAME;
						if ( a >= LAME ) a -= LAME;

						for ( int p = j - 1 ; p < j + 2 ; p++ ) {
							b = p;
							if ( b < 0 ) b += LAME;
							if ( b >= LAME ) b -= LAME;

							tmp[ i ][ j ] += distance[ a ][ b ];
							count++;

							if ( NULL != bs ) {
								//if ( 0==i&&j==0 ) fprintf( bs, "count:%d , add %f -> %f\n", count, distance[ a ][ b ], tmp[ i ][ j ] );
							}
							continue;

							if ( q == i && p == j ) {
								for ( int k = 0 ; k < 2 ; k++ ) {
									tmp[ i ][ j ] += distance[ a ][ b ];
									count++;
								}
							}
						}
					}
					tmp[ i ][ j ] /= count;
					if ( NULL != bs ) {
						//if ( 0==i&&j==0 ) fprintf( bs, "average it: count:%d -> %f\n", count, tmp[ i ][ j ] );
					}
				}
			}
			for ( int i = 0 ; i < LAME ; i++ ) {
				for ( int j = 0 ; j < LAME ; j++ ) {
					if ( 0 != distance[ i ][ j ] ) {
						points[ i ][ j ].scale( tmp[ i ][ j ] / distance[ i ][ j ] );
					}
				}
			}
		}

		void shakeUp() {
			float shake = 0.001;
			for ( int i = 0 ; i < LAME ; i++ ) {
				for ( int j = 0 ; j < LAME ; j++ ) {
					this->points[ i ][ j ].scale( 1 + rand() * shake - rand() * shake );
				}
			}
		}

		void scale( float f ) {
			for ( int i = 0 ; i < LAME ; i++ ) {
				for ( int j = 0 ; j < LAME ; j++ ) {
					this->points[ i ][ j ].scale( f );
				}
			}
		}
		void print( FILE *bs ) {
			this->bs = bs;
			return; // check it out java: c++ doesn't act like a whiney little bitch...
			for ( int i = 0 ; i < LAME ; i++ ) {
				for ( int j = 0 ; j < LAME ; j++ ) {
					this->points[ i ][ j ].print( bs );
				}
			}
		}
};

class ThePlanetAss {
	private:
		FILE *bs;
		Spheroid planet;
		Spheroid water;
		Spheroid atmosphere;
		Spheroid moon;
		GLuint textureId;
		float rotation_angle;
	public:
		ThePlanetAss() {
			bs = fopen( "/tmp/bs.txt", "w" );
			textureId = -1;

			// make the moon weirdly, not perfectly round
			for ( int i = 0 ; i < 100 ; i++ ) {
				//this->smack( moon );
				moon.shakeUp();
			}
			moon.smooth();

			this->planet.print( bs );
		}

		~ThePlanetAss() {
			GLuint ID = this->textureId;
			glDeleteTextures( 1, &ID );
		}

		void setup() {
			glShadeModel( GL_SMOOTH );
			glClearColor( 0.0f, 0.0f, 0.0f, 0.0f );
			glClearDepth( 1.0f ); 
			glEnable( GL_DEPTH_TEST );
			glDepthFunc( GL_LEQUAL );
			glHint( GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST );

			glShadeModel( GL_FRONT_AND_BACK );
			glEnable( GL_LIGHTING );
			glEnable( GL_COLOR_MATERIAL );
			glColorMaterial( GL_FRONT_AND_BACK, GL_AMBIENT_AND_DIFFUSE );
			glEnable( GL_LIGHT0 );

			glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

			setupFog();
			setupWater();
		}

		void setupFog() {
			// fog-tastic!

			//GLuint filter;                      // Which Filter To Use
			GLuint fogMode[]= { GL_EXP, GL_EXP2, GL_LINEAR };   // Storage For Three Types Of Fog
			GLuint fogfilter= 0;                    // Which Fog To Use
			GLfloat fogColor[4]= {0.5f, 0.5f, 0.5f, 1.0f};      // Fog Color

			glFogi(GL_FOG_MODE, fogMode[fogfilter]);        // Fog Mode
			glFogfv(GL_FOG_COLOR, fogColor);            // Set Fog Color
			glFogf(GL_FOG_DENSITY, 0.15f);              // How Dense Will The Fog Be
			glHint(GL_FOG_HINT, GL_DONT_CARE);          // Fog Hint Value
			glFogf(GL_FOG_START, 1.0f * 5);             // Fog Start Depth
			glFogf(GL_FOG_END, 5.0f);               // Fog End Depth
			glEnable(GL_FOG);                   // Enables GL_FOG
		}

		void setupWater() {
			// water texture

			GLuint ID;
			GLuint funk = GL_MODULATE;
			//GLuint clamp = GL_REPEAT;

			glGenTextures( 1, &ID );
			glBindTexture( GL_TEXTURE_2D, ID );

			this->textureId = ID;

			int width = 2;
			int height = 2;

			glTexEnvf( GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, funk );

#define BLU 255,0,0,230

			GLubyte pixels[] = { BLU,BLU,BLU,BLU };

			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR); 
			glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_BGRA, GL_UNSIGNED_BYTE, pixels );
			glGenerateMipmap(GL_TEXTURE_2D);  //Generate mipmaps now!!!
		}

		void resize( GLfloat width, GLfloat height ) {
			glViewport( 0, 0, width, height );
			glMatrixMode( GL_PROJECTION );
			glLoadIdentity();
			gluPerspective( 45.0f, width / height, 0.1f, 100.0f );
			glMatrixMode( GL_MODELVIEW );
			glLoadIdentity();
		}

		void smack( Spheroid &spheroid ) {
			int i = random() % LAME;
			int j = random() % LAME;
			float d = ( random() % 100 / 100.0 - 0.5 );
			//fprintf( bs, "stank: %d,%d : %f\n", i, j, d );

			spheroid.upsAndDowns( i, j, d );
			spheroid.shakeUp();
		}

		void iterate() {
			int numberOfIterations = 200;
			for ( int i = 0 ; i < numberOfIterations ; i++ ) {
				smack( this->planet );
				if ( 0 == ( i + ( ( int ) this->rotation_angle ) ) % 100 ) {
					this->planet.smooth();
				}
			}
		}

		void draw() {
			glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT ); 
			glLoadIdentity(); 

			glTranslatef( 0.0f, 0.0f, -4.0f );

			this->rotation_angle += 1;

			//glRotatef( 1*rotation_angle, 1.0f, 0.0f, 0.0f );
			glRotatef( 100, 1.0f, 0.0f, 0.0f );
			glRotatef( 0*rotation_angle, 0.0f, 1.0f, 0.0f );
			glRotatef( 1*rotation_angle, 0.0f, 0.0f, 1.0f );

			//glRotatef( rotation_angle, 0.0f, 1.0f, 0.0f );
			//glRotatef( 0, 0.0f, 1.0f, 0.0f );
			//glRotatef( rotation_angle, 0.0f, 0.0f, 1.0f );
		
			if ( 0 ) {
				glBegin( GL_LINES );     
				glColor3f( 1,0,0 );
				glVertex3f( 0,+1.5,0 );
				glVertex3f( 0,-1.5,0 );
				glEnd();
			}
			
			glBegin( GL_TRIANGLES ); 
			this->planet.draw( 0 );
			glEnd();

			// black lines
			if ( 0 ) {
				glBegin( GL_LINES );     
				this->planet.draw( 0 );
				glEnd();
			}

			glPushMatrix(); 
			{
				// move the moon!
				glRotatef( rotation_angle, 0.0f, 1.0f, 1.0f );
				glTranslatef( 1.6, 0, 0 );

				glScalef( 0.1, 0.1, 0.1 );
				glBegin( GL_TRIANGLES ); 
				this->moon.draw( 4 );
				glEnd();
			}
			glPopMatrix();



	
			glEnable( GL_BLEND ); 
			{
				glBegin( GL_TRIANGLES ); 
				this->water.draw( 2 );
				glEnd();

				glScalef( 1.3, 1.3, 1.3 );
				glBegin( GL_TRIANGLES ); 
				this->water.draw( 3 );
				glEnd();
			} 
			glDisable( GL_BLEND );
			
/*
			glBegin( GL_LINES ); 
			glColor3f( 1, 0, 0 );
			for ( int i = 0 ; i < LAME ; i++ ) { this->points[ i ][ LAME - 1 ].vert(); }
			for ( int i = 0 ; i < LAME ; i++ ) { this->water[ i  ][ LAME - 1 ].vert(); }
			glEnd();
*/
			glFlush(); 
		}
};

////////////////////////////////////////////////////////////////////////////////////////////
// you can probly ignore the rest of this madness

// objective c scat:
@interface      PlanetAssOpenGLView : NSOpenGLView {} @end
@implementation PlanetAssOpenGLView - (BOOL)isOpaque { return NO; } @end

@interface PlanetAssView : ScreenSaverView 
{
	/*srand([[NSDate date] timeIntervalSince1970]);*/
	ThePlanetAss *thePlanetAss;
	PlanetAssOpenGLView *glView;

/* frck this! 
		IBOutlet id configSheet;
		IBOutlet id drawFilledShapesOption;
		IBOutlet id drawOutlinedShapesOption;
		IBOutlet id drawBothOption;
*/
}

- (void)setUpOpenGL;

@end


@implementation PlanetAssView

- (void)startAnimation
{
    [super startAnimation];
}

- (void)stopAnimation
{
    [super stopAnimation];
}

- (BOOL)hasConfigureSheet
{
    return NO;//YES; frck this!
}

- (NSWindow*)configureSheet
{
/* frck this!
	if (!configSheet) {
		if (![NSBundle loadNibNamed:@"ConfigureSheet" owner:self]) 
		{
			NSLog( @"Failed to load configure sheet." );
			NSBeep();
		}
	}

	return configSheet;
*/
	return nil;
}

/* frck this
- (IBAction)cancelClick:(id)sender {
	  [[NSApplication sharedApplication] endSheet:configSheet];
}
*/

- (id)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
	self = [super initWithFrame:frame isPreview:isPreview];
	
	if (self) 
	{   
		thePlanetAss = new ThePlanetAss();
		
		NSOpenGLPixelFormatAttribute attributes[] = { 
			NSOpenGLPFAAccelerated,
			NSOpenGLPFADepthSize, 16,
			NSOpenGLPFAMinimumPolicy,
			NSOpenGLPFAClosestPolicy,
			0 };  
		NSOpenGLPixelFormat *format;
		
		format = [[[NSOpenGLPixelFormat alloc] 
				   initWithAttributes:attributes] autorelease];

		glView = [[PlanetAssOpenGLView alloc] initWithFrame:NSZeroRect 
										 pixelFormat:format];
		
		if (!glView)
		{             
			NSLog( @"Couldn't initialize OpenGL view." );
			[self autorelease];
			return nil;
		} 
		
		[self addSubview:glView]; 
		[self setUpOpenGL]; 
		
		[self setAnimationTimeInterval:1/30.0];
	}
	
	return self;
}

- (void)dealloc
{
	[glView removeFromSuperview];
	[glView release];
	delete thePlanetAss;
	[super dealloc];
}

- (void)setUpOpenGL
{  
	[[glView openGLContext] makeCurrentContext];
	thePlanetAss->setup();
}

- (void)setFrameSize:(NSSize)newSize
{
	[super setFrameSize:newSize];
	[glView setFrameSize:newSize]; 
	[[glView openGLContext] makeCurrentContext];
	thePlanetAss->resize( (GLfloat)newSize.width , (GLfloat)newSize.height );
	[[glView openGLContext] update];
}


- (void)animateOneFrame
{   	     
	// Adjust our state 
	thePlanetAss->iterate();
	[self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect
{  
	[super drawRect:rect];
	[[glView openGLContext] makeCurrentContext];
	thePlanetAss->draw();
}

@end
