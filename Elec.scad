/*
 *
 +--------------------------------------------------------------------------
 * History
 * Date       Version Author      Description
 * 2019/02/11  v1     Ph.Gregoire Initial version
 +-------------------------------------------------------------------------
 *
 *  This work is licensed under the 
 *  Creative Commons Attribution 3.0 Unported License.
 *  To view a copy of this license, visit
 *    http://creativecommons.org/licenses/by/3.0/ 
 *  or send a letter to 
 *    Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
*/

use <TronxyX5S\phgUtils_v1.scad>

// Thickness
thk=5;

// Depth of champfer
champDepth=2;

// Rounding radius
rnd=2;


// squashing width
squash=thk;

// Screw shaft and head diameters
screwDiam=4.5;
screwHead=8;

// Tolerance...
_EPSILON=GET_EPSILON();

module _screwHole() {
    cyl_eps(screwDiam,thk);
    trcone(0,0,thk-(screwHead-screwDiam)/2,screwDiam,screwHead,(screwHead-screwDiam)/2+_EPSILON*2);
}

module _screwHoles(dx,dy) {
    // Screw holes and seats
    screwOff=screwDiam+screwHead;
    
    trz(-_EPSILON) 
    if(dx-screwOff<screwHead) {
        // One hole along x
        for(s=[1,-1]) tr(0,s*(dy-screwOff)/2) _screwHole();
    } else cornersPos(dx-screwOff,dy-screwOff) _screwHole();
}

function bw(diam)=diam+thk+2*squash;
function zOff(diam)=diam/2+thk/2;

module _hullcyl(length,diam,rotz=0,halfTapper=false) {
    bw=bw(diam);
    rot(0,0,rotz) hull() {
        tr(0,-bw/2) if(halfTapper)
            intersection() {
                tr(-rnd*2) roundedFlatBox(length+rnd*2,bw,thk,rnd*2);
                cube([length,bw,thk]);
            }
        else roundedFlatBox(length,bw,thk,rnd*2);
        trrotcyl(0,0,zOff(diam),0,90,0,diam+thk,length);
    }
}

module _hull() {
    #union() children();
}

module _hullify(h,dz) {
    hull() {
        trz(-dz)
        linear_extrude(height=h) 
        offset(r=squash)
        projection() children();
        children();
    }
}

/* Champfered cylinder */
module _cylchamp(length,diam,rotz=0) {
    rot(rotz,90) {
        // Inner tube
        cyl_eps(diam,length-champDepth+_EPSILON);
        
        // Champfer
        trcone(0,0,length-champDepth,diam,diam+champDepth/2,thk+_EPSILON);
    }
}


module straightSupport(dx,dy,diam) difference() {    
    union() {
        // support
        roundedFlatBox(dx,dy,thk,rnd,center=true);
        
        // support and outer tube
        tr(-dx/2) _hullcyl(dx,diam);
    }

    trrot(-_EPSILON-dx/2,0,zOff(diam),0,90,0) {
        // Inner tube
        cyl_eps(diam,dx);
        
        // Champfers
        cylinder(d1=diam+champDepth/2,d2=diam,champDepth+_EPSILON);
        trcone(0,0,dx-champDepth+2*_EPSILON,diam,diam+champDepth/2,champDepth+_EPSILON);
    }
    
    _screwHoles(dx,dy);
}

module cornerSupport(dx,dy,diam) difference() {
    bw=bw(diam);
    union() {
        // support
        roundedFlatBox(dx,dy,thk,rnd,center=true);
        
        // support and outer tube
        _hullcyl(dx/2,diam);
        _hullcyl(dy/2,diam,90);
        
        // Central sphere
        hull() {
            tr(-bw/2,-bw/2) roundedFlatBox(bw,bw,thk,rnd*2);
            trz(zOff(diam)) sphere(d=diam+thk);
        }
    }

    trz(zOff(diam)) {
        _cylchamp(dx/2,diam);
        _cylchamp(dy/2,diam,-90);
        sphere(d=diam);
    }
    
    _screwHoles(dx,dy);
}

module quartTorus(r,d) {
    intersection() {
        rot(0,0,180) trcube(0,0,-d/2,r+d/2,r+d/2,d);
        rotate_extrude(convexity = 2) {
            tr(r) circle(d=d);
        }
    }
}

module roundedSquare(d,h) {
    cylinder(d=d,h=h);
    trcube(-d/2,0,0,d/2,d/2,h);
    trcube(0,-d/2,0,d/2,d/2,h);
    trcube(0,0,0,d/2,d/2,h);
}

module roundSupport(dx,dy,diam) {
    // Offset of the torus (torus radius)
    offT=diam/2+2*thk;
    screwOff=screwDiam+screwHead;
    rOff=dx/2-screwOff;
    dOff=(dx-screwOff)*2;
    difference() {
        union() {
            // support
            intersection() {
                roundedFlatBox(dx,dy,thk,rnd,center=true);                
                tr(rOff,rOff,0) roundedSquare(dOff,thk);
            }
            
            // support and outer tube
            tr(offT) _hullcyl(dx/2-offT,diam,0,true);
            tr(0,offT) _hullcyl(dy/2-offT,diam,90,true);
            
            // Rounding
            tr(offT,offT,zOff(diam)) _hullify(thk,diam/2+thk/2) quartTorus(offT,diam+thk);
        }

        trz(zOff(diam)) {
            // Hole
            tr(offT-_EPSILON) _cylchamp(dx/2-offT+_EPSILON,diam);
            tr(0,offT-_EPSILON) _cylchamp(dy/2-offT+_EPSILON,diam,-90);
            
            // Rounding hole
            tr(offT,offT) quartTorus(offT,diam);
        }
    
        _screwHoles(dx,dy);
        tr(rOff-(dOff-screwOff)*sqrt(2)/4,rOff-(dOff-screwOff)*sqrt(2)/4,-_EPSILON) _screwHole();
    }
}

$fn=GET_FN_CYL();

//tr(40) 
straightSupport(20,60,20+_EPSILON*2);
//tr(-40) 
//cornerSupport(80,60,20+1);

//roundSupport(60,60,20+_EPSILON*2);