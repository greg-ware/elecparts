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


/* Set details accuracy */
$fn=$preview?GET_FN_CYL():64;

// Tolerance...
_EPSILON=$preview?GET_EPSILON():0;

use <phgUtils_v2.scad>
echo("Generating with $fn=",$fn," _EPSILON=",_EPSILON);

// Thickness
thk=5;

// Depth of champfer
champDepth=2;

// Rounding radius
rnd=2;

// spreading width, this is the factor by which elements hulls are extended
squash=5; //thk;

// Screw shaft and head diameters
screwDiam=4.5;
screwHead=8.4;
screwSeatHeight=(screwHead-screwDiam)/2;
screwStyleFlat=true;

_SHAFTMAX=100;  // arbitrary height of screw shaft

/* =================================================================== */
/* Utility modules and functions                                       */
/*                                                                     */
/* =================================================================== */

/* Determine distance of screw from edge */
function _screwDistFromEdge(sD=screwDiam,sH=screwHead) = (sD+sH)/2;

function _plateBorder(diam,screwOff=2*_screwDistFromEdge(),_eps=_EPSILON)=(diam+_eps)/2+squash+screwOff;
function _plateInnerBorder(diams,screwOff,_eps=_EPSILON)=_plateBorder(diams[0],screwOff,_eps);
function _plateOuterBorder(diams,screwOff,_eps=_EPSILON)=_plateBorder(diams[len(diams)-1],screwOff,_eps);

/* Drill one screw hole */
module _screwHole(diam=screwDiam,head=screwHead,seat=screwSeatHeight,style=screwStyleFlat) {
    cyl_eps(diam,thk);
    if(style)
        trcyl(0,0,thk-seat,head,seat+_EPSILON*2);
    else
        trcone(0,0,thk-seat,diam,head,seat+_EPSILON*2);
    
    // Extend the screw shaft upwards
    trcyl(0,0,thk,head,_SHAFTMAX);
}

module _trScrewHole(tx,ty,tz=0,diam=screwDiam,head=screwHead,seat=screwSeatHeight,style=screwStyleFlat) {
    tr(tx,ty,tz) _screwHole(diam,head,seat,style);
}

module _twoXScrewHoles(dx,dy,offset=undef,diam=screwDiam,head=screwHead,seat=screwSeatHeight,style=screwStyleFlat) {
    
    off=is_undef(offset)?_screwDistFromEdge(diam,head)*2:offset;
    
    // Two holes along x axis
    dxOff=(dx==0)?0:(dx>0)?(dx-off)/2:(dx+off)/2;
    for(s=[1,-1]) _trScrewHole(dxOff,s*(dy-off)/2,0,diam,head,seat,style);
}

module _twoYScrewHoles(dx,dy,offset=undef,diam=screwDiam,head=screwHead,seat=screwSeatHeight,style=screwStyleFlat) {
    
    off=is_undef(offset)?_screwDistFromEdge(diam,head)*2:offset;
    
    // Two holes along x axis
    dyOff=(dy==0)?0:(dy>0)?(dy-off)/2:(dy+off)/2;
    for(s=[1,-1]) _trScrewHole(s*(dx-off)/2,dyOff,0,diam,head,seat,style);
}

/* Drill screw Holes along X axis. One or two holes depending if there is enough length */
module _screwHoles(dx,dy,diam=screwDiam,head=screwHead,seat=screwSeatHeight,style=screwStyleFlat) {
    // Screw holes and seats
    offset=_screwDistFromEdge(diam,head)*2;
    
    trZ(-_EPSILON) 
    if(dx-offset<head) {
        // Two holes along x axis
        _twoXScrewHoles(0,dy,offset,diam,head,seat,style);
    } else {
        // one hole per corner
        cornersPos(dx-offset,dy-offset) _screwHole(diam,head,seat,style);
    }
}

function bw(diam)=diam+thk+2*squash;
function zOff(diam)=diam/2+thk/2;

/* Cylinder with base hulled */
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
        trZ(-dz)
        linear_extrude(height=h) 
        offset(r=squash)
        projection() children();
        children();
    }
}

/* Create either a plain union or a hull of the children */
module hullOrUnion(doHull) {
    if(doHull) _hull() children();
    else union() children();
}

/* Champfered cylinder */
module _cylchamp(length,diam,rotz=0,both=false) {
    rot(rotz,90) {
        // Inner tube
        cyl_eps(diam,length-champDepth+_EPSILON);
        
        // Champfer
        trcone(0,0,length-champDepth,diam,diam+champDepth/2,champDepth+_EPSILON);
        
        if(both) {
            trcone(0,0,-_EPSILON,diam+champDepth/2,diam,champDepth+_EPSILON);
        }
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

//translate([-50,0,0])
//multipleStraight(20,[20+.5,20+.5,16+.5],[24,22],false,_EPSILON*3);

/* Generate multiple parallel supports
    diamSpacings contains an array of spacings followed by diameter
*/
module multipleStraight(dx,diams,spacings=[],thickHull=false,_eps=_EPSILON) {
    difference() {
        for(p=[1:2]) _multipleStraightPart(p,true,dx,diams,spacings,thickHull,_eps);
        for(p=[1:2]) _multipleStraightPart(p,false,dx,diams,spacings,thickHull,_eps);
    }
}

/* Generates the parts for multiple supports
    partID 1: support (base and screw holes)
    partID 2: tubes
    partID 3: tubes with bridge (inner tubes only)

    partID 11: only hullbase no tube
    partID 12: only tubes no hull

    partID 33: bridge all but first
    partID 43: bridge all but last

    partID 1xx: Same as xx but no first screw
    partID 1yyy: Same as yyyy but no champfers
*/
module _multipleStraightPart(partID,isOuter,dx,diams,spacings,thickHull=false,_eps=_EPSILON) {
    diams=is_list(diams)?diams:[diams];
    diamsMax=len(diams)-1;
    spacings=is_list(spacings)?spacings:((diamsMax<1)?[]:[for(i=[0:diamsMax-1]) spacings]);
    
    // Offsets to position screw holes and rounding of base plate
    screwOff=_screwDistFromEdge()*2;
    
    noChampfer=floor(partID/1000)==1;
    noFirstScrew=floor((partID%1000)/100)==1;
    partID=partID%100;
    
    // Inner and outer border plate width
    plateInnerBorder=noFirstScrew?0:_plateInnerBorder(diams,screwOff,_eps);
    plateOuterBorder=_plateOuterBorder(diams,screwOff,_eps);
    
    /* Compute length of base plate */
    dy=plateInnerBorder+sigma(spacings)+plateOuterBorder;
    
    /* Compute positions of tubes.
       If thera are as many or more spacings as tubes, the first element 
       is the offset of the first tube, otherwise of the second
    */
    yS=(len(spacings)<len(diams))?
        [for(iD=[0:diamsMax]) plateInnerBorder+sigma0(spacings,iD)]:
        [for(iD=[0:diamsMax]) plateInnerBorder+sigma(spacings,iD)];
    
    isSupport=partID==1;
    isTubes=partID==2 || partID==11 || partID==12 || partID==3 || partID==33 || partID==43;
    
    if(isOuter) {
        // support
        if(isSupport) tr(0,dy/2) roundedFlatBox(dx,dy,thk,rnd,center=true);
        
        // outer tubes
        //if(partID==2 || partID==11 || partID==12)
        if(isTubes)
        hullOrUnion(thickHull && (partID==2)) {
            for(iD=[0:diamsMax]) {
                hullOrUnion(!thickHull && (partID==2)) {
                    tr(-dx/2,yS[iD]) {
                        if(partID==2 || partID==11) _hullcylPart(1,dx,diams[iD]+_eps);
                        if(partID==2 || partID==12) _hullcylPart(2,dx,diams[iD]+_eps);
                    }
                }
            }
        }
    } else {
        // support screw holes
        if(!noFirstScrew) tr(0,dy/2) _screwHoles(dx,dy);
        else _trScrewHole(0,dy-_screwDistFromEdge());
        
        // Inner tubes
        //if(partID==2 || partID==3)
        if(isTubes) for(iD=[0:diamsMax]) {
            diam=diams[iD]+_eps;
            trrot(-_EPSILON-dx/2,yS[iD],zOff(diam),0,90,0) {
                straightHole(diam,dx,noChampfer?undef:true);

                if(partID==3 || (partID==33 && iD>0) || (partID==43 && iD<diamsMax)) {
                    // Bridge type of tube, remove and champfer bottom part
                    trcube_eps(0,-diam/2,0,zOff(diam)+_EPSILON,diam,dx+_EPSILON);
                    
                    if(!noChampfer)
                    for(dy_a=[[-diam/2-champDepth/4,180],[diam/2,90]]) {
                        rot(0,90) tr(-champDepth,dy_a[0],0)
                            prism(champDepth,champDepth/4,zOff(diam)+_EPSILON,dy_a[1]);
                        rot(180,-90) tr(-champDepth+dx+_EPSILON+_EPSILON,dy_a[0],0)
                            prism(champDepth,champDepth/4,zOff(diam)+_EPSILON,dy_a[1]);
                    }
                }
            }
        }            
    }
}

module trStacked(i,diams,spacingsZ) {
    trZ((i==0)?0:(spacingsZ[i-1]==undef)?max(diams[i-1]):spacingsZ[i-1]) children();
}

/* Generate multiple parallel supports 
    diamSpacings contains an array of spacings followed by diameter
    supportLevel defines which level is used to compute the base support size
    If there are as many or more spacings as tubes, the first is taken as an offset
*/
module multipleStackedStraight(dx,diams,spacings=[],spacingsZ=undef,supportLevel=1,bridge=true,_eps=0) {
    spacingsZ=is_list(spacingsZ)?spacingsZ:[spacingsZ];
    
    thickHull=true; // No other way for mutiple
    difference() {
        union() {
            // Support for selected level, not translated
            _multipleStraightPart(1,true,dx,diams[supportLevel],spacings[supportLevel],thickHull,_eps);

            _hull() {
                // Support and tubes for bottom level
                _multipleStraightPart(2,true,dx,diams[0],spacings[0],thickHull,_eps);
                
                // tubes only for all levels above
                for(i=[1:len(diams)-1]) {
                    _multipleStraightPart(11,true,dx,diams[i],spacings[i],thickHull,_eps);
                    trStacked(i,diams,spacingsZ)
                        _multipleStraightPart(12,true,dx,diams[i],spacings[i],thickHull,_eps);
                }
            }
        }
        
        union() {
            // Support screws for selected level
            _multipleStraightPart(1,false,dx,diams[supportLevel],spacings[supportLevel],thickHull,_eps);
            
            // Tubes holes for all levels
            for(i=[0:len(diams)-1])
                trStacked(i,diams,spacingsZ)
                    _multipleStraightPart((bridge && i==0)?3:2,false,dx,diams[i],spacings[i],thickHull,_eps);
        }
    }
}

/* Short hand for a straight support */
module straightSupport(dx,dy,diam,thickHull=false,_eps=0) {
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
            trZ(zOff(diam)) sphere(d=diam+thk);
        }
    }

    trZ(zOff(diam)) {
        _cylchamp(dx/2,diam);
        _cylchamp(dy/2,diam,-90);
        sphere(d=diam);
    }
    
    _screwHoles(dx,dy);
}

/* Support with a rounded corner shape */
module roundSupport(dx,dy,diam) {
    // Offset of the torus (torus radius)
    offT=diam/2+2*thk;
    screwOff=_screwDistFromEdge()*2;
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

        trZ(zOff(diam)) {
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

/* Generate a hull around a turning pipe */
module turningPipeHull(inlet,outlet,thk,diam) {
    offT=diam/2+2*thk;
    
    // inlet
    tr(offT) _hullcyl(inlet-offT,diam,0,true);
    
    // Rounding
    tr(offT,offT,zOff(diam)) _hullify(thk,diam/2+thk/2) quarterTorus(offT,diam+thk);

    // outlet    
    tr(0,offT) _hullcyl(outlet-offT,diam,90,true);
}
/* Straight hole with champfers at both ends if both is false, only first side has champfer, if undef, no champfer */
module straightHole(diam,length,both=true) {
    // Inner tube
    cyl_eps(diam,length);
                
    // Champfers
    if(!is_undef(both)) {
        cylinder(d1=diam+champDepth/2,d2=diam,champDepth+_EPSILON);
        if(both) {
            trcone(0,0,length-champDepth+2*_EPSILON,diam,diam+champDepth/2,champDepth+_EPSILON);
        }
    }
}

/* Turning cylinder with champfers (to bore a hole */
module turningHole(inlet,outlet,thk,diam) {
    trZ(zOff(diam)) {
        offT=diam/2+2*thk;
        // inlet
        tr(offT-_EPSILON) _cylchamp(inlet-offT+_EPSILON,diam);
        
        // rounding
        tr(offT,offT) quarterTorus(offT,diam);

        // outlet
        tr(0,offT-_EPSILON) _cylchamp(outlet-offT+_EPSILON,diam,-90);
    } 
}

//tee(20+.5,25+.5,29,false);
module tee(diam,length,teeLength,oneSidePlate=false) {
    plateBorder=(oneSidePlate)?diam/2:_plateBorder(diam/2);
    difference() {
        union() {
            // support base
            tr(-length,-plateBorder)
            roundedFlatBox(length*2,teeLength+plateBorder,thk,rnd);
            
            // Two corners
            turningPipeHull(length,teeLength,thk,diam);
            rotZ() turningPipeHull(teeLength,length,thk,diam);
            
            // Straight tube with its base
            tr(-length) _hullcyl(length*2,diam);
            
            // fill the top of the crossing area
            trZ(thk/2+diam) _crossTee(diam,thk/2);
            
            // Optionally handle children nodes
            if($children>1) children(0);
        }
        union() {
            // Screw holes for plate
            tr(0,teeLength/2) _twoYScrewHoles(length*2,teeLength);
            if(!oneSidePlate) {
                tr(0,-plateBorder/2) _twoYScrewHoles(length*2,-plateBorder);
            }
            
            // Two corners
            turningHole(length,teeLength,thk,diam);
            rotZ() turningHole(teeLength,length,thk,diam);
            
            // Straight tube
            tr(-length-_EPSILON,0,diam/2+thk/2) rotY() straightHole(diam,length*2);
            
            // Remove inner spikes that won't print hanging from ceiling
            trZ(thk/2) _crossTee(diam,diam);
            
            // Optionally handle children nodes
            if($children>1) for(c=[1:$children-1])children(c);
                else if($children>0) children(0);
        }
    }
}

/* Generate the flat area at the crossing of tubes */
module _crossTee(diam,h) {
    offT=diam/2+2*thk;
    tr(0,offT/2,h/2)
    difference() {
        cube([offT*2,offT,h],center=true);
        trcyl_eps(offT,offT/2,0,offT*2,h+$_EPSILON,center=true);
        trcyl_eps(-offT,offT/2,0,offT*2,h+$_EPSILON,center=true);
    }
}

//tr(-20,52.5) rotZ(180) multipleStraight(20,[20+.5,20+.5,16+.5],[24,22],false,_EPSILON*3);

teeWithSideStraight(20+.5,25+.5,25+.5,10,[16+.5],[22]);
module teeWithSideStraight(diam,length,teeLength,sidePipesLength,sidePipeDiams,spacings) {
    sidePipeDiams=[for(i=[0:len(sidePipeDiams)]) i==0?diam:sidePipeDiams[i-1] ];

    tee(diam,length,teeLength,true) {
        rotZ(180) for(p=[1101,1102]) _multipleStraightPart(p,true,sidePipesLength,sidePipeDiams,spacings,true);
        rotZ(180) for(p=[1101,1133]) {
            _multipleStraightPart(p,false,sidePipesLength,sidePipeDiams,spacings);
            _multipleStraightPart(p,false,2*length,sidePipeDiams,spacings);
        }
//        tr(-length-_EPSILON,-spacings[0],sidePipeDiams[0]/2+thk/2) rotY() straightHole(sidePipeDiams[0],length*2);
    }
}

module multipleRound(diams,spacingsX=[],spacingsY=[],_eps=0) {
    diams=is_list(diams)?diams:[diams];
    
    diamsMax=len(diams)-1;
    spacingsX=is_list(spacingsX)?spacingsX:((diamsMax<1)?[]:[for(i=[0:diamsMax-1]) spacingsX]);
    spacingsY=is_list(spacingsY)?((len(spacingsY)==0)?spacingsX:spacingsY):((diamsMax<1)?[]:[for(i=[0:diamsMax-1]) spacingsY]);
    
    // Offsets to position screw holes and rounding of base plate
    screwOff=_screwDistFromEdge()*2;
    
    plateInnerBorder=_plateInnerBorder(diams,screwOff,_eps);
    plateOuterBorder=_plateOuterBorder(diams,screwOff,_eps);
    
    dx=plateInnerBorder+sigma(spacingsX)+plateOuterBorder;
    dy=plateInnerBorder+sigma(spacingsY)+plateOuterBorder;
       
    rOff=dx/2-screwOff;
    dOff=(dx-screwOff)*2;
    torusOuterDiam=3*diams[diamsMax]/2+thk+squash;
    
    xS=[for(iD=[0:diamsMax]) plateInnerBorder+sigma0(spacingsX,iD)];
    yS=[for(iD=[0:diamsMax]) plateInnerBorder+sigma0(spacingsY,iD)];
        
    plateRoudingRadius=plateOuterBorder+torusOuterDiam/2;
    difference() {
        union() {
            // rounded base plate
            intersection() {
                roundedFlatBox(dx,dy,thk,rnd,center=true);
                rot(0,0,180) tr(-dx/2,-dy/2) roundedRect(dx,dy,plateRoudingRadius,thk);
            }
                for(iD=[0:diamsMax]) {
                // outer tube
                tr(dx/2-xS[iD],dy/2-yS[iD]) {
                    turningPipeHull(xS[iD],yS[iD],thk,diams[iD]+_eps);
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
            
            /* Screw holes */
            screwPos=_screwDistFromEdge();
            
            // Inner hole 
            tr(dx/2-screwPos,dy/2-screwPos,-_EPSILON) _screwHole();

            // Two outer holes
            for(s=[1,-1])
            tr(s*(dx/2-screwPos),-s*(dy/2-screwPos),-_EPSILON) _screwHole();
            
            // Far outer hole
            _roundPlateOuterHole(plateRoudingRadius,dx,dy,screwPos) _screwHole();
        }
    }
}

/* Round plate far outer hole */
module _roundPlateOuterHole(plateRoudingRadius,dx,dy,screwPos) {
    // Compute center qnd radius of plate's outer rounding circle
    cx=-dx/2+plateRoudingRadius;
    cy=-dy/2+plateRoudingRadius;
    rc=plateRoudingRadius-screwPos;
    tr(cx-rc/sqrt(2),cy-rc/sqrt(2),-_EPSILON) children();
}

/* Draw one the 3 children depending on ID. 0 for round, 1 straight along X, 2 along Y */
module _drawSubParts(xS,yS,spacingsX,spacingsY,iD,numberOfTurning) {
    tr(-xS[iD],-yS[iD])
    if(iD>=numberOfTurning && (spacingsX[iD-1]==undef || spacingsY[iD-1]==undef)) {
        // Use a straight connector
        if(spacingsX[iD-1]==undef) {
            // Along X
            children(1);
        } else {
            // Along Y
            children(2);
        }
    } else {
        // Round
        children(0);
    }
}

/* Special setup with several straight and round */
module straightRound(diamsRnd,diamsStr,spacingsX=[],spacingsY=[],_eps=0) {
    diamsStr=is_list(diamsStr)?diamsStr:[diamsStr];
    diamsStrMax=len(diamsStr)-1;
    
    diamsRnd=is_list(diamsRnd)?diamsRnd:[diamsStr];
    diamsRndMax=len(diamsRnd)-1;
    
    diams=concat(diamsRnd,diamsStr);
    diamsMax=len(diams)-1;
    
    // Offsets to position screw holes and rounding of base plate
    screwOff=_screwDistFromEdge()*2;
    
    plateInnerBorder=_plateInnerBorder(diams,screwOff,_eps);
    plateOuterBorder=_plateOuterBorder(diams,screwOff,_eps);
    
    dx=plateInnerBorder+sigma(spacingsX)+plateOuterBorder;
    dy=plateInnerBorder+sigma(spacingsY)+plateOuterBorder;
       
    rOff=dx/2-screwOff;
    dOff=(dx-screwOff)*2;
    
    xS=[for(iD=[0:diamsMax]) plateInnerBorder+sigma0(spacingsX,iD)];
    yS=[for(iD=[0:diamsMax]) ((iD>=len(diamsRnd))?0:plateInnerBorder+sigma0(spacingsY,iD))];
    
    difference() {
        union() {
            // rounded base plate
            roundedFlatBox(dx,dy,thk,rnd,center=true);

            // Draw turning or straight tubes
            for(iD=[0:diamsMax]) _drawSubParts(xS,yS,spacingsX,spacingsY,iD,len(diamsRnd)) {
                // turning tube
                tr(dx/2,dy/2) turningPipeHull(xS[iD],yS[iD],thk,diams[iD]+_eps);
                
                // straight tube along X
                tr(0,dy/2) _hullcyl(dx,diams[iD]+_eps);
                
                // straight tube along Y
                trrot(dx/2,-dy/2,0,0,0,90) _hullcyl(dy,diams[iD]+_eps);
            }            
        }
        union() {
            // Collection of tubes
            for(iD=[0:diamsMax]) _drawSubParts(xS,yS,spacingsX,spacingsY,iD,len(diamsRnd)) {
                 // turning tube
                tr(dx/2,dy/2) turningHole(xS[iD],yS[iD],thk,diams[iD]+_eps);

                // straight hole along X
                tr(0,dy/2) straightHole(diams[iD]+_eps,dx);

                // straight hole along Y with champfers on both ends
                trrot(dx/2,-dy/2,zOff(diams[iD]+_eps),0,90,90) {
                    straightHole(diams[iD]+_eps,dy);
                }
            }
            
            // Screw holes
            screwPos=_screwDistFromEdge();
            
            for(xH=[dx/2-screwPos,-(dx/2-screwPos)])
                for(yH=[dy/2-screwPos,-(dy/2-screwPos)]) 
                    tr(xH,yH,-_EPSILON) _screwHole();
        }
    }
}

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
//multipleStraight(20,[20+.5,20+.5,16+.5],[24,22],false,_EPSILON*3);

/* Stacked tubes straight support to add 1x16 and 2x20 on top of existing 16 and 20 spaced by 4cm */
//multipleStackedStraight(20,[[16+2,20+2],[20+1,20+1,16+1]],[[40],[25,25]],[],1,_EPSILON*3);
//multipleStackedStraight(20,[[16+2,20+2],[20+.5,20+.5,16+.5]],[[40],[25,25]],[],1,_EPSILON*3);
//multipleStackedStraight(20,[[16+2,20+2],[20+.5,20+.5,16+.5]],[[50],[25,25]],[25],1,_EPSILON*3);
//multipleStackedStraight(20,[[16+2,16+2,20+2],[20+.5,20+.5,16+.5]],[[30,25],[25,25]],[25],0,_EPSILON*3);

//multipleStackedStraight(20,[[20+1,20+1,16+1],[20+.5]],[[25,23],[13]],[20],0,_EPSILON*3);

/* Simple single round corner, diameter 20 */
//multipleRound(20+.5,_eps=_EPSILON*2);

/* Multiple rounded corner supports */
//multipleRound([20+.5,16+.5],[22],[20],_eps=_EPSILON*2);
//multipleRound([16+.5,20+.5],[22],[20],_eps=_EPSILON*2);

/* Quadruple rounded corner supports 20-20-20-16 */
//multipleRound([20,20,20,16],[45,45,20],[25,25,25],_EPSILON*2);

/* Multiple rounded tubes 20-16-20 */
//multipleRound([20,16,20],[25,30],[30,40],_eps=_EPSILON*2);

/* Merging tubes of different sizes */
//multipleRound([16+.5,20+.5],22,0,_eps=_EPSILON*2);

/* Complex merging tubes, two 20 inputs merging into two 20 outputs */
//multipleRound([20,20,20],[ 30,0] ,[0,25] ,_eps=_EPSILON*2);

/* One rounded, one straight */
//straightRound([20],[20],[23],[undef],_eps=_EPSILON*2);

/* Two straight, two rounded */
//straightRound([20+.3,20+.3],[20+.3,16+.2],[23,23,20],[23],_eps=_EPSILON*2);

//multipleStackedStraight(20,[[16+.5,20+.5,20+.5],[20+0.8]],[[41,24],[17]],[8],0,false,_eps=_EPSILON*3);
