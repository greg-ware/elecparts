/*
 *
 +-------------------------------------------------------------------------
 * History
 * Date       Version Author      Description
 * 2019/02/11  v1     Ph.Gregoire Initial version
 * 2019/04/09  v1.1   Ph.Gregoire Multiple Straight and Round capabilities
 +-------------------------------------------------------------------------
 *
 *  This work is licensed under the 
 *  Creative Commons Attribution 3.0 Unported License.
 *  To view a copy of this license, visit
 *    http://creativecommons.org/licenses/by/3.0/ 
 *  or send a letter to 
 *    Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
*/

/* ======================
    Readme
   
    # Introduction
    This openscad module allows to produce electrical cabling system
    fastening elements, either to hold straight tubes in place, or to 
    serve as rounded corner elements.
   
    # Warning
    USE AT YOUR OWN RISK! No live wire should be exposed inside those
    elements, their role is just to fasten the electrical tubes in place.
    Especially, keep in mind that PLA or ABS printed elements may not
    have enough strength and may break loose.
   
    # Usage
    There are essentially two module to use as entry points:
   
    1. Straight fastening clamps:
        `multipleStraight(width,diameters,spacings,[epsilon])`
        Will place multiple rings of specified diameters at specified spacings
        For example, `multipleStraight(20,[16,20,16],[25,35])` will generate
        fastenings for 3 tubes of diameters 16, 20 and 16, spaced at 
        25 and 35 from each others, of width 20.
        The optional epsilon parameter will make the tubes a bit wider:
        * A value of 2*_EPSILON is good for a tight fit
        * A value of 3*_EPSILON is good for a loose fit
        Screw holes are placed by 2 or 4 depending on the width.
        
        Note that:
        * a single-tube fastener can be obtained with the form
        `multipleStraight(width,diameter,_eps=epsilon)`
        * If the spacings are the same they can be specified with a single 
        integer rather than an array, i.e.  `multipleStraight(width,diameters,spacing,[epsilon])`
        
    2. Rounded corner fastenings:
        `multipleRound(diameters,spacingsX,spacingsT,[epsilon])`
        Will create an series of corner tubes of the specified diameters,
        where the spacings along the X and Y sides are as specified by 
        the two arrays.
        For example, `multipleRound([20,16,20],[25,30],[30,40],_eps=_EPSILON*2)`
        will generate 3 tubes spaced 25,30 along the X axis and 30,40 along the Y axis.
       
        Note that:
        * A single-tube corner can be obtained with `multipleRound(diam,_eps=epsilon)`
        * When an even spacing is required, it can be specified as a
        single integer rather than an array, i.e. 
        `multipleRound(diams,spacingX,spacingY,_eps=epsilon)`
        * if `spacingY` is omitted or of 0 length (i.e. `[]`), it will default to `spacingsX`
        * To make merging tubes, specify the spacing as 0
        * Tubes always turn right, for the opposite, apply a mirror operation
*/

use <phgUtils_v1.scad>

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
    rot(0,0,rotz) _hull() {
        tr(0,-bw/2) if(halfTapper)
            intersection() {
                tr(-rnd*2) roundedFlatBox(length+rnd*2,bw,thk,rnd*2);
                cube([length,bw,thk]);
            }
        else roundedFlatBox(length,bw,thk,rnd*2);
        trrotcyl(0,0,zOff(diam),0,90,0,diam+thk,length);
    }
}

/* Hull wrapper for faster preview */
module _hull() {
    if($preview) children();
    else hull() children();
}

module _hullify(h,dz) {
    _hull() {
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

/* Repeat children with translation from an array */
module repeatTr(offsets,i=0) {
    translate(offsets[i]) {
        children();
        if(i+1<len(offsets)) {
            repeatTr(offsets,i+1) children();
        }
    }
}

/* adjusted index */
function ix(arr,i)=(i<0)?(len(arr)-1):i;

/* Adds items from an array */
function sigma(arr,i=-1,step=1) = (len(arr)<=0)?0:(((arr[ix(arr,i)])==undef?0:arr[ix(arr,i)])+((ix(arr,i)<step)?0:sigma(arr,ix(arr,i)-step,step)));

/* Add items from an array shifted by one element */
function sigma0(arr,i) = ((i==0)?0:sigma(arr,i-1));

/* Generate multiple parallel supports 
    diamSpacings contains an array of spacings followed by diameter
*/
module multipleStraight(dx,diams,spacings=[],_eps=0) {
    diams=(len(diams)==undef)?[diams]:diams;
    diamsMax=len(diams)-1;
    spacings=(len(spacings)!=undef)?spacings:((diamsMax<1)?[]:[for(i=[0:diamsMax-1]) spacings]);
    
    // Offsets to position screw holes and rounding of base plate
    screwOff=screwDiam+screwHead;
    
    // Inner and outer border plate width
    plateInnerBorder=(diams[0]+_eps)/2+thk+screwOff;
    plateOuterBorder=(diams[diamsMax]+_eps)/2+thk+screwOff;
    
    dy=plateInnerBorder+sigma(spacings)+plateOuterBorder;
    yS=[for(iD=[0:diamsMax]) plateInnerBorder+sigma0(spacings,iD)];
        
    echo("dx=",dx," dy=",dy);
    
    difference() {
        union() {
            // support
            tr(0,dy/2) roundedFlatBox(dx,dy,thk,rnd,center=true);
            
            for(iD=[0:diamsMax]) {
                // support and outer tube
                tr(-dx/2,yS[iD]) _hullcyl(dx,diams[iD]+_eps);
            }
        }
        for(iD=[0:diamsMax]) {
            diam=diams[iD]+_eps;
            trrot(-_EPSILON-dx/2,yS[iD],zOff(diam),0,90,0) {
                // Inner tube
                cyl_eps(diam,dx);
                
                // Champfers
                cylinder(d1=diam+champDepth/2,d2=diam,champDepth+_EPSILON);
                trcone(0,0,dx-champDepth+2*_EPSILON,diam,diam+champDepth/2,champDepth+_EPSILON);
            }
        }
        
        tr(0,dy/2) _screwHoles(dx,dy);
    }

}

module straightSupport(dx,dy,diam,_eps=0) difference() {
    multipleStraight(dx,dy,[dy/2,diam],_eps);
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
        _hull() {
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

/* Square with one rounded corner */
module roundedSquare(d,h) {
    cylinder(d=d,h=h);
    trcube(-d/2,0,0,d/2,d/2,h);
    trcube(0,-d/2,0,d/2,d/2,h);
    trcube(0,0,0,d/2,d/2,h);
}

/* Utility to have a rectangle with the far most corner rounded */
module roundedRect(dx,dy,r,h) {
    union() {
        intersection() {
            trcyl(dx-r,dy-r,h/2,d=r*2,h=h,center=true);
            trcube(dx-r/2,dy-r/2,h/2,r,r,h,center=true);
        }
        trcube(0,dy-r,0,dx-r,r,h);
        trcube(dx-r,0,0,r,dy-r,h);
        trcube(0,0,0,dx-r,dy-r,h);
    }
}

/* Support with a rounded corner shape
*/
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

module roundHull(inlet,outlet,thk,diam) {
    offT=diam/2+2*thk;
    
    // inlet
    tr(offT) _hullcyl(inlet-offT,diam,0,true);
    
    // Rounding
    tr(offT,offT,zOff(diam)) _hullify(thk,diam/2+thk/2) quartTorus(offT,diam+thk);

    // outlet    
    tr(0,offT) _hullcyl(outlet-offT,diam,90,true);
}

module roundHole(inlet,outlet,thk,diam) {
    trz(zOff(diam)) {
        offT=diam/2+2*thk;
        // inlet
        tr(offT-_EPSILON) _cylchamp(inlet-offT+_EPSILON,diam);
        
        // rounding
        tr(offT,offT) quartTorus(offT,diam);

        // outlet
        tr(0,offT-_EPSILON) _cylchamp(outlet-offT+_EPSILON,diam,-90);
    } 
}

module multipleRound(diams,spacingsX=[],spacingsY=[],_eps=0) {
    diams=(len(diams)==undef)?[diams]:diams;
    
    diamsMax=len(diams)-1;
    spacingsX=(len(spacingsX)!=undef)?spacingsX:((diamsMax<1)?[]:[for(i=[0:diamsMax-1]) spacingsX]);
    spacingsY=(len(spacingsY)!=undef)?((len(spacingsY)==0)?spacingsX:spacingsY):((diamsMax<1)?[]:[for(i=[0:diamsMax-1]) spacingsY]);
    
    // Offsets to position screw holes and rounding of base plate
    screwOff=screwDiam+screwHead;
    
    plateInnerBorder=(diams[0]+_eps)/2+thk+screwOff;
    plateOuterBorder=(diams[diamsMax]+_eps)/2+thk+screwOff;
    
    dx=plateInnerBorder+sigma(spacingsX)+plateOuterBorder;
    dy=plateInnerBorder+sigma(spacingsY)+plateOuterBorder;
       
    rOff=dx/2-screwOff;
    dOff=(dx-screwOff)*2;
    torusOuterDiam=3*diams[diamsMax]/2+thk+squash;
    echo("Size: dx=",dx," dy=",dy);
    
    xS=[for(iD=[0:diamsMax]) plateInnerBorder+sigma0(spacingsX,iD)];
    yS=[for(iD=[0:diamsMax]) plateInnerBorder+sigma0(spacingsY,iD)];
    difference() {
        union() {
            // rounded base plate
            intersection() {
                roundedFlatBox(dx,dy,thk,rnd,center=true);
                rot(0,0,180) tr(-dx/2,-dy/2) roundedRect(dx,dy,plateOuterBorder+torusOuterDiam/2,thk);
            }
            for(iD=[0:diamsMax]) {
                // outer tube
                tr(dx/2-xS[iD],dy/2-yS[iD]) {
                    roundHull(xS[iD],yS[iD],thk,diams[iD]+_eps);
                }
            }
        }
        union() {
            for(iD=[0:diamsMax]) {
                // inner tube hole
                tr(dx/2-xS[iD],dy/2-yS[iD]) {
                    roundHole(xS[iD],yS[iD],thk,diams[iD]+_eps);
                }
            }
            
            // Screw holes
            //_screwHoles(dx,dy);
            screwPos=(screwDiam+screwHead)/2;
            
            tr(dx/2-screwPos,dy/2-screwPos,-_EPSILON) _screwHole();
            tr(-(dx/2-screwPos),dy/2-screwPos,-_EPSILON) _screwHole();
            tr(dx/2-screwPos,-(dy/2-screwPos),-_EPSILON) _screwHole();
            
            // 
            r=torusOuterDiam/2+thk*2+screwPos*2;
            r2=r/sqrt(2);
            
            torx=(plateOuterBorder+torusOuterDiam/2)-dx/2;
            tory=(plateOuterBorder+torusOuterDiam/2)-dy/2;
            tr(torx-r2,tory-r2,-_EPSILON) _screwHole();
            //trcyl(torx,tory,0,r*2,100);
        }
    }
}

module _dispatch(diamsMax,spacingsX,spacingsY,iD) {
    if(iD>0 && (spacingsX[iD-1]==undef || spacingsY[iD-1]==undef)) {
        // Use a straight connector
        if(spacingsX[iD-1]==undef) {
            children(1);
        } else {
            children(2);
        }
    } else {
        children(0);
    }
}

/* Special setup with one straight and one round */
module straightRound(diams,spacingsX=[],spacingsY=[],_eps=0) {
//module multipleRound(diams,spacingsX=[],spacingsY=[],_eps=0) {
    diams=(len(diams)==undef)?[diams]:diams;
    
    // Offsets to position screw holes and rounding of base plate
    screwOff=screwDiam+screwHead;
    diamsMax=len(diams)-1;
    
    plateInnerBorder=(diams[0]+_eps)/2+thk+screwOff;
    plateOuterBorder=(diams[diamsMax]+_eps)/2+thk+screwOff;
    
    dx=plateInnerBorder+sigma(spacingsX)+plateOuterBorder;
    dy=plateInnerBorder+sigma(spacingsY)+plateOuterBorder;
       
    rOff=dx/2-screwOff;
    dOff=(dx-screwOff)*2;
    torusOuterDiam=3*diams[diamsMax]/2+thk+squash;
    echo("Size: dx=",dx," dy=",dy);
    
    xS=[for(iD=[0:diamsMax]) plateInnerBorder+sigma0(spacingsX,iD)];
    yS=[for(iD=[0:diamsMax]) plateInnerBorder+sigma0(spacingsY,iD)];
    
    difference() {
        union() {
            // rounded base plate
            intersection() {
                roundedFlatBox(dx,dy,thk,rnd,center=true);
                //rot(0,0,180) tr(-dx/2,-dy/2) roundedRect(dx,dy,plateOuterBorder+torusOuterDiam/2,thk);
            }
            for(iD=[0:diamsMax]) _dispatch(diamsMax,spacingsX,spacingsY,iD) {
                tr(dx/2-xS[iD],dy/2-yS[iD]) {
                    roundHull(xS[iD],yS[iD],thk,diams[iD]+_eps);
                }
                tr(-xS[iD],dy/2-yS[iD]) _hullcyl(dx,diams[iD]+_eps);
                trrot(dx/2-xS[iD],-yS[iD],0,0,0,90) _hullcyl(dy,diams[iD]+_eps);
            }            
        }
        union() {
            for(iD=[0:diamsMax]) _dispatch(diamsMax,spacingsX,spacingsY,iD) {
                tr(dx/2-xS[iD],dy/2-yS[iD]) {
                    roundHole(xS[iD],yS[iD],thk,diams[iD]+_eps);
                }
                cube();
                diam=diams[iD]+_eps;
                trrot(dx/2-xS[iD],-yS[iD],zOff(diam),0,90,90) {
                    // Inner tube
                    cyl_eps(diam,dy);
                    
                    // Champfers
                    #cylinder(d1=diam+champDepth/2,d2=diam,champDepth+_EPSILON);
                    #trcone(0,0,dy-champDepth+2*_EPSILON,diam,diam+champDepth/2,champDepth+_EPSILON);
                }
            }
            
            // Screw holes
            //_screwHoles(dx,dy);
            screwPos=(screwDiam+screwHead)/2;
            
            tr(dx/2-screwPos,dy/2-screwPos,-_EPSILON) _screwHole();
            tr(-(dx/2-screwPos),dy/2-screwPos,-_EPSILON) _screwHole();
            tr(dx/2-screwPos,-(dy/2-screwPos),-_EPSILON) _screwHole();
            
            // 
            r=torusOuterDiam/2+thk*2+screwPos*2;
            r2=r/sqrt(2);
            
            torx=(plateOuterBorder+torusOuterDiam/2)-dx/2;
            tory=(plateOuterBorder+torusOuterDiam/2)-dy/2;
            tr(torx-r2,tory-r2,-_EPSILON) _screwHole();
            //trcyl(torx,tory,0,r*2,100);
        }
    }
}

/* Set details accuracy */
$fn=GET_FN_CYL();
//$fn=8;

/* Generate a short (2 holes) straight support */
//tr(40) 
//straightSupport(20,60,20+_EPSILON*2);
//multipleStraight(20,20,_EPSILON*3);

/* Generate a long (4 holes) straight support */
//tr(40) 
//straightSupport(40,60,20+_EPSILON*2);
//tr(-40) multipleStraight(40,20,_EPSILON*3);
//multipleStraight(20,[20,20],45,_EPSILON*3);

/* Generate a corner support */
//tr(-40) 
//cornerSupport(80,60,20+1);

/* Generate a rounded support */
//roundSupport(60,60,20+_EPSILON*2);

/* Generate supports for 4 tubes of diams 16,20,20,20 spaced by 25mm */
//tr(40) multipleStraight(20,[20,20,20,16],25,_EPSILON*3);

/* Support that matches the 20-20-20-26/45-45-20 rounded one */
//multipleStraight(20,[20,20,20,16],[45,45,20],_EPSILON*3);

/* Rounded support */
//multipleRound([20,20,20,16],[45,45,20],[25,25,25],_EPSILON*2);
//multipleRound(20,_eps=_EPSILON*2);

/* Round one input two outputs */
//multipleRound([20,16,20],[25,30],[30,40],_eps=_EPSILON*2);

/* Single round corner, diameter 20 */
//multipleRound(20,_eps=_EPSILON*2);

/* Merging tubes */
//multipleRound([20,20],30,0,_eps=_EPSILON*2);

/* Complex merging tubes */
multipleRound([20,20,20],[ 30,0] ,[0,25] ,_eps=_EPSILON*2);

//straightRound([20,20],[25],[undef],_eps=_EPSILON*2);
