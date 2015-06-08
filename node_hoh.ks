// Delta vee math stolen from http://en.wikipedia.org/wiki/Hohmann_transfer_orbit#Calculation
// Phase angle math stolen from https://docs.google.com/document/d/1IX6ykVb0xifBrB4BRFDpqPO6kjYiLvOcEo3zwmZL0sQ/edit

run lib_ui.

function approachDistance {
  local ratio is target:mass / ship:mass.

  if ratio > 100000 {
    return 2 * target:radius + target:atm:height.
  } else {
    return 0.
  }
}

function synodicPeriod {
  parameter o1, o2.

  if o1:period > o2:period {
    local o is o2.
    set o2 to o1.
    set o1 to o.
  }

  return 1 / ( (1 / o1:period) - (1 / o2:period) ).
}

if body <> target:body {
  uiWarning("Node", "Incompatible orbits").
  local die is 1 / 0.
}
if ship:obt:eccentricity > 0.1 {
  uiWarning("Node", "Eccentric ship e=" + round(ship:obt:eccentricity, 1)).
  local die is 1 / 0.
}
if target:obt:eccentricity > 0.1 {
  uiWarning("Node", "Eccentric target e=" +  + round(target:obt:eccentricity, 1)).
  local die is 1 / 0.
}
local ri is abs(obt:inclination - target:obt:inclination).
if ri > 0.1 {
  uiWarning("Node", "Bad alignment ri=" +  + round(ri, 1)).
  local die is 1 / 0.
}

local r1 is (ship:obt:semimajoraxis + ship:obt:semiminoraxis) / 2.
local r2 is (target:obt:semimajoraxis + target:obt:semiminoraxis) / 2.
local dt is 0.
local approach is 0.

if r2 > r1 {
  set approach to approachDistance().
  set dt to ship:obt:period / 4.
} else {
  set approach to approachDistance().
  set dt to target:obt:period / 4.
}

local dv is sqrt(body:mu / r1) * (sqrt( (2*(r2-approach)) / (r1+r2-approach) ) - 1).
local pt is 0.5 * ((r1+r2) / (2*r2))^1.5.
local ft is pt - floor(pt).

// angular distance that target will travel during transfer
local theta is 360 * ft.
// necessary phase angle for vessel burn
local phi is 180 - theta.
// angular velocity of vessel
local omega is (ship:velocity:orbit:mag / (body:radius+ship:altitude))  * (180/constant():pi).

local T is time:seconds.
local Tmax is T + 1.5 * synodicPeriod(ship:obt, target:obt).
local done is false.

until done = true or T > Tmax {
  local p1 is positionat(ship, T) - body:position.
  local p2 is positionat(target, T) - body:position.
  local v1 is velocityat(ship, T):orbit.
  local v2 is velocityat(target, T):orbit.

  // unsigned magnitude of the orbital angle between ship and target
  local angleT is vang(p1, p2).
  // if r2 > r1, then norm:y is negative when ship is "behind" the target
  local norm is vcrs(p1, p2).
  // < 0 if ship is on opposite side of planet
  local dot is vdot(v1, v2).

  local eta is 0.

  if r2 > r1 {
    set eta to (angleT - phi) / omega.
  } else {
    set eta to (angleT + phi) / omega.
  }

  if r2 > r1 and norm:y > 0 {
    uiDebugNode(T, "ship is ahead of target").
    set T to T + dt.
  } else if r2 < r1 and norm:y < 0 {
    uiDebugNode(T, "ship is behind target").
    set T to T + dt.
  } else if (r2 > r1 and dot > 0) or (r2 < r1 and dot < 0) {
    uiDebugNode(T, "ship is opposite target").
    set T to T + dt.
  } else if eta > ship:obt:period {
    uiDebugNode(T, "eta is too far").
    set T to T + dt.
  } else {
    set T to T + eta.
    set done to true.
  }
}

if done {
  local p1 is positionat(ship, T) - body:position.
  local p2 is positionat(target, T) - body:position.
  local angleT is vang(p1, p2).
  uiDebugNode(T, "found window! angleT=" + round(angleT, 1) + " phi=" + round(phi, 1)).
  add node(T, 0, 0, dv).
} else {
  uiError("Node", "NO SOLUTION").
  local die is 1 / 0.
}