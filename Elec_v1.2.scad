/* Electrical tubings generator
 *
 * Requires OpenSCAD 2019.05
 *
 +-------------------------------------------------------------------------
 * History
 * Date       Version Author      Description
 * 2019/02/11 v1      Ph.Gregoire Initial version
 * 2019/04/09 v1.1    Ph.Gregoire Multiple Straight and Round capabilities
 * 2020/04/30 v1.2    Ph.Gregoire Add Stacked supports, thickHull
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
        `multipleStraight(width,diameters,spacings,thickHull=false,[epsilon])`
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
        integer rather than an array, i.e.  `multipleStraight(width,diameters,spacing,thickHull,[epsilon])`
    1b. Stacked straight supports:
        `multipleStackedStraight(dx,diams,spacings=[],spacingsZ=undef,_eps=0) `
        Designed to add tubing over existing ones.
        The first row has arches, the subsequent rows come on top, and a single thick hull is used arond all of them. 
        The spacingsZ specifies the Z-distance between two rows. If left to undef, the max height of the row below is used. 
        
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

use <phgUtils_v2.scad>

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
_EPSILON=$preview?GET_EPSILON():0;

_SHAFTMAX=100;  // arbitrary height of screw shaft
/* Drill one screw hole */
module _screwHole() {
    cyl_eps(screwDiam,thk);
    trcone(0,0,thk-(screwHead-screwDiam)/2,screwDiam,screwHead,(screwHead-screwDiam)/2+_EPSILON*2);
    // Extend the screw shaft upwards
    trcyl(0,0,thk,screwHead,_SHAFTMAX);
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

/* Cylinder with base hulled
*/
module _hullcyl(length,diam,rotz=0,halfTapper=false) {
    rot(0,0,rotz) _hull() {
        _hullcylPart(1,length,diam,halfTapper);
        _hullcylPart(2,length,diam,halfTapper);
    }
}

/* Hull cylinder part 
    partID 1: support
    partID 2: cylinder
*/
module _hullcylPart(partID,length,diam,halfTapper=false) {
    bw=bw(diam);
    if(partID==1) {
        tr(0,-bw/2) if(halfTapper)
            intersection() {
                tr(-rnd*2) roundedFlatBox(length+rnd*2,bw,thk,rnd*2);
                cube([length,bw,thk]);
            }
        else roundedFlatBox(length,bw,thk,rnd*2);
    }
    if(partID==2) {
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

/* adjusted array indexing, negative indices return last index */
function ix(arr,i)=(i<0)?(len(arr)-1):i;

/* Adds items from an array, up to the */
function sigma(arr,i=-1,step=1) = (len(arr)<=0)?0:(((arr[ix(arr,i)])==undef?0:arr[ix(arr,i)])+((ix(arr,i)<step)?0:sigma(arr,ix(arr,i)-step,step)));

/* Add items from an array shifted by one element */
function sigma0(arr,i) = ((i==0)?0:sigma(arr,i-1));

/* Generate multiple parallel supports 
    diamSpacings contains an array of spacings followed by diameter
*/
module multipleStraight(dx,diams,spacings=[],thickHull=false,_eps=0) {
    difference() {
        for(p=[1:2]) _multipleStraightPart(p,true,dx,diams,spacings,thickHull,_eps);
        for(p=[1:2]) _multipleStraightPart(p,false,dx,diams,spacings,thickHull,_eps);
    }
}
/* Create either a plain union or a hull of the children
*/
module hullOrUnion(doHull) {
    if(doHull) _hull() children();
    else union() children();
}

/* Generates the parts for multiple supports
    partID 1: support (base and screw holes)
    partID 2: tubes
    partID 3: tubes with no bottom (inner tubes only)

    partID 11: only hullbase no tube
    partID 12: only tubes no hull
*/
module _multipleStraightPart(partID,isOuter,dx,diams,spacings,thickHull,_eps) {
    diams=is_list(diams)?diams:[diams];
    diamsMax=len(diams)-1;
    spacings=is_list(spacings)?spacings:((diamsMax<1)?[]:[for(i=[0:diamsMax-1]) spacings]);
    
    // Offsets to position screw holes and rounding of base plate
    screwOff=screwDiam+screwHead;
    
    // Inner and outer border plate width
    plateInnerBorder=(diams[0]+_eps)/2+thk+screwOff;
    plateOuterBorder=(diams[diamsMax]+_eps)/2+thk+screwOff;
    
    /* Compute length of base plate */
    dy=plateInnerBorder+sigma(spacings)+plateOuterBorder;
    
    /* Compute positions of tubes.
       If thera are as many or more spacings as tubes, the first element 
       is the offset of the first tube, otherwise of the second
    */
    yS=(len(spacings)<len(diams))?
        [for(iD=[0:diamsMax]) plateInnerBorder+sigma0(spacings,iD)]:
        [for(iD=[0:diamsMax]) plateInnerBorder+sigma(spacings,iD)];
        
    if(isOuter) {
        // support
        if(partID==1)
        tr(0,dy/2) roundedFlatBox(dx,dy,thk,rnd,center=true);
        
        // outer tubes
        if(partID==2 || partID==11 || partID==12)
        hullOrUnion(thickHull && (partID==2)) for(iD=[0:diamsMax]) {
            hullOrUnion(!thickHull && (partID==2)) {
                tr(-dx/2,yS[iD]) {
                    if(partID==2 || partID==11) _hullcylPart(1,dx,diams[iD]+_eps);
                    if(partID==2 || partID==12) _hullcylPart(2,dx,diams[iD]+_eps);
                }
            }
        }
    } else {
        // support screw holes
        if(partID==1)
        tr(0,dy/2) _screwHoles(dx,dy);

        // Inner tubes
        if(partID==2 || partID==3)
        for(iD=[0:diamsMax]) {
            diam=diams[iD]+_eps;
            trrot(-_EPSILON-dx/2,yS[iD],zOff(diam),0,90,0) {
                // Inner tube
                cyl_eps(diam,dx);
                if(partID==3)
                    trcube_eps(0,-diam/2,0,zOff(diam)+_EPSILON,diam,dx+_EPSILON);
                
                // Champfers
                ch=champDepth/2;
                cylinder(d1=diam+ch,d2=diam,champDepth+_EPSILON);
                trcone(0,0,dx-champDepth+2*_EPSILON,diam,diam+ch,champDepth+_EPSILON);

                if(partID==3)
                    for(dy_a=[[-diam/2-ch/2,180],[diam/2,90]]) {
                        rot(0,90) tr(-champDepth,dy_a[0],0)
                            prism(champDepth,ch/2,zOff(diam)+_EPSILON,dy_a[1]);
                        rot(180,-90) tr(-champDepth+dx+_EPSILON+_EPSILON,dy_a[0],0)
                            prism(champDepth,ch/2,zOff(diam)+_EPSILON,dy_a[1]);
                    }
            }
        }            
    }
}

module trStacked(i,diams,spacingsZ) {
    trz((i==0)?0:(spacingsZ[i-1]==undef)?max(diams[i-1]):spacingsZ[i-1]) children();
}

/* Generate multiple parallel supports 
    diamSpacings contains an array of spacings followed by diameter
    supportLevel defines which level is used as the base
    If there are as many or more spacings as tubes, the first is taken as an offset
*/
module multipleStackedStraight(dx,diams,spacings=[],spacingsZ=undef,supportLevel=1,_eps=0) {
    spacingsZ=is_list(spacingsZ)?spacingsZ:[spacingsZ];
        
    difference() {
        union() {
            // Support for selected level, not translated
            _multipleStraightPart(1,true,dx,diams[supportLevel],spacings[supportLevel],false,_eps);

            _hull() {
                // Support and tubes for bottom level
                _multipleStraightPart(2,true,dx,diams[0],spacings[0],false,_eps);
                
                // tubes only for all levels above
                for(i=[1:len(diams)-1]) {
                    _multipleStraightPart(11,true,dx,diams[i],spacings[i],false,_eps);
                    trStacked(i,diams,spacingsZ)
                        _multipleStraightPart(12,true,dx,diams[i],spacings[i],false,_eps);
                }
            }
        }
        
        union() {
            // Support screws for selected level
            _multipleStraightPart(1,false,dx,diams[supportLevel],spacings[supportLevel],false,_eps);
            
            // Tubes holes for all levels
            for(i=[0:len(diams)-1])
                trStacked(i,diams,spacingsZ)
                    _multipleStraightPart(i==0?3:2,false,dx,diams[i],spacings[i],false,_eps);
        }
    }
}

module straightSupport(dx,dy,diam,thickHull=false,_eps=0) difference() {
    multipleStraight(dx,dy,[dy/2,diam],thickHull,_eps);
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
            tr(offT,offT,zOff(diam)) _hullify(thk,diam/2+thk/2) quarterTorus(offT,diam+thk);
        }

        trz(zOff(diam)) {
            // Hole
            tr(offT-_EPSILON) _cylchamp(dx/2-offT+_EPSILON,diam);
            tr(0,offT-_EPSILON) _cylchamp(dy/2-offT+_EPSILON,diam,-90);
            
            // Rounding hole
            tr(offT,offT) quarterTorus(offT,diam);
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
    tr(offT,offT,zOff(diam)) _hullify(thk,diam/2+thk/2) quarterTorus(offT,diam+thk);

    // outlet    
    tr(0,offT) _hullcyl(outlet-offT,diam,90,true);
}

/* Turning cylinder with champfers (to bore a hole */
module turningHole(inlet,outlet,thk,diam) {
    trz(zOff(diam)) {
        offT=diam/2+2*thk;
        // inlet
        tr(offT-_EPSILON) _cylchamp(inlet-offT+_EPSILON,diam);
        
        // rounding
        tr(offT,offT) quarterTorus(offT,diam);

        // outlet
        tr(0,offT-_EPSILON) _cylchamp(outlet-offT+_EPSILON,diam,-90);
    } 
}

module multipleRound(diams,spacingsX=[],spacingsY=[],_eps=0) {
    diams=is_list(diams)?diams:[diams];
    
    diamsMax=len(diams)-1;
    spacingsX=is_list(spacingsX)?spacingsX:((diamsMax<1)?[]:[for(i=[0:diamsMax-1]) spacingsX]);
    spacingsY=is_list(spacingsY)?((len(spacingsY)==0)?spacingsX:spacingsY):((diamsMax<1)?[]:[for(i=[0:diamsMax-1]) spacingsY]);
    
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
            union() {
            intersection() {
                roundedFlatBox(dx,dy,thk,rnd,center=true);
                rot(0,0,180) tr(-dx/2,-dy/2) roundedRect(dx,dy,plateOuterBorder+torusOuterDiam/2,thk);
            }
            trcyl(-dx/2,-dy/2,0,plateOuterBorder+torusOuterDiam/2);
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
                    turningHole(xS[iD],yS[iD],thk,diams[iD]+_eps);
                }
            }
            
            // Screw holes
            screwPos=(screwDiam+screwHead)/2;
            
            // Inner hole 
            tr(dx/2-screwPos,dy/2-screwPos,-_EPSILON) _screwHole();

            // Two outer holes
            for(s=[1,-1])
            #tr(s*(dx/2-screwPos),-s*(dy/2-screwPos),-_EPSILON) _screwHole();
            
            // Far outer hole
            r=torusOuterDiam/2+thk*2+screwPos*2;
            r2=r/sqrt(2);
            
            torx=(plateOuterBorder+torusOuterDiam/2)-dx/2;
            tory=(plateOuterBorder+torusOuterDiam/2)-dy/2;
            tr(torx-r2,tory-r2,-_EPSILON) _screwHole();
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
    diams=is_list(diams)?diams:[diams];
    
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
                    turningHole(xS[iD],yS[iD],thk,diams[iD]+_eps);
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
//multipleStraight(20,20,false,_EPSILON*3);

/* Generate a long (4 holes) straight support */
//tr(40) 
//straightSupport(40,60,20+_EPSILON*2);
//tr(-40) multipleStraight(40,20,false,_EPSILON*3);
//multipleStraight(20,[20,20],45,false,_EPSILON*3);

/* Generate a corner support */
//tr(-40) 
//cornerSupport(80,60,20+1);

/* Generate a rounded support */
//roundSupport(60,60,20+_EPSILON*2);
//roundSupport(50,50,16);
//roundSupport(46,46,16+.2);

/* Generate supports for 4 tubes of diams 16,20,20,20 spaced by 25mm */
//tr(40) multipleStraight(20,[20,20,20,16],25,false,_EPSILON*3);

/* Support that matches the 20-20-20-26/45-45-20 rounded one */
//multipleStraight(20,[20,20,20,16],[45,45,20],false,_EPSILON*3);
/* Same but with thick hull */
//multipleStraight(20,[20,20,20,16],[45,45,20],true,_EPSILON*3);

//multipleStraight(30,[20+.5,16+.5],[22],true,_EPSILON*3);

/* Stacked tubes straight support to add 1x16 and 2x20 on top of existing 16 and 20 spaced by 4cm */
//multipleStackedStraight(20,[[16+2,20+2],[20+1,20+1,16+1]],[[40],[25,25]],[],1,_EPSILON*3);
//multipleStackedStraight(20,[[16+2,20+2],[20+.5,20+.5,16+.5]],[[40],[25,25]],[],1,_EPSILON*3);
//multipleStackedStraight(20,[[16+2,20+2],[20+.5,20+.5,16+.5]],[[50],[25,25]],[25],1,_EPSILON*3);
//multipleStackedStraight(20,[[16+2,16+2,20+2],[20+.5,20+.5,16+.5]],[[30,25],[25,25]],[25],0,_EPSILON*3);

//multipleStackedStraight(20,[[20+1,20+1,16+1],[20+.5]],[[25,23],[13]],[20],0,_EPSILON*3);

/* Rounded support */
//multipleRound([20,20,20,16],[45,45,20],[25,25,25],_EPSILON*2);
//multipleRound(20,_eps=_EPSILON*2);

/* Round one input two outputs */
//multipleRound([20,16,20],[25,30],[30,40],_eps=_EPSILON*2);
multipleRound([20+.5,16+.5],[20],[20],_eps=_EPSILON*2);

/* Single round corner, diameter 20 */
//multipleRound(20,_eps=_EPSILON*2);

/* Merging tubes */
//multipleRound([20,20],30,0,_eps=_EPSILON*2);

/* Complex merging tubes */
//multipleRound([20,20,20],[ 30,0] ,[0,25] ,_eps=_EPSILON*2);

//straightRound([20,20],[25],[undef],_eps=_EPSILON*2);
