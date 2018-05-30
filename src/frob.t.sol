pragma solidity ^0.4.23;

import "ds-test/test.sol";
import "ds-token/token.sol";

import './frob.sol';
import {Dai20} from './transferFrom.sol';
import {Adapter} from './join.sol';

import {WarpFlip as Flipper} from './flip.t.sol';
import {WarpFlop as Flopper} from './flop.t.sol';
import {WarpFlap as Flapper} from './flap.t.sol';


contract WarpVat is Vat {
    uint48 _era; function warp(uint48 era_) public { _era = era_; }
    function era() public view returns (uint48) { return _era; }

    function woe() public view returns (uint w) {
        w = dai[this] > 0 ? 0 : uint(-dai[this]);
    }

    function suck(address guy, uint wad) public {
        dai[guy] += int(wad);
    }
}

contract FrobTest is DSTest {
    WarpVat vat;
    Dai20   pie;

    DSToken gold;
    bytes32 gold_ilk;

    Adapter adapter;

    Flipper flip;
    Flopper flop;
    Flapper flap;

    DSToken gov;

    function try_frob(bytes32 ilk, int ink, int art) public returns(bool) {
        bytes4 sig = bytes4(keccak256("frob(bytes32,int256,int256)"));
        return address(vat).call(sig, ilk, ink, art);
    }

    function ray(uint wad) internal pure returns (uint) {
        return wad * 10 ** 9;
    }

    function setUp() public {
        gov = new DSToken('GOV');
        gov.mint(100 ether);

        vat = new WarpVat();
        pie = new Dai20(vat);

        flap = new Flapper(vat, gov);
        flop = new Flopper(vat, gov);
        gov.setOwner(flop);

        vat.taff(flap);
        vat.toff(flop);

        gold = new DSToken("GEM");
        gold.mint(1000 ether);

        gold_ilk = vat.form();
        adapter = new Adapter(vat, gold_ilk, gold);
        gold.approve(adapter);
        adapter.join(1000 ether);

        vat.file(gold_ilk, "spot", ray(1 ether));
        vat.file(gold_ilk, "line", 1000 ether);
        vat.file("Line", 1000 ether);
        flip = new Flipper(vat, gold_ilk);
        vat.tiff(gold_ilk, flip);

        gold.approve(vat);
        gov.approve(flap);
    }

    function test_join() public {
        gold.mint(500 ether);
        assertEq(gold.balanceOf(this),     500 ether);
        assertEq(gold.balanceOf(adapter), 1000 ether);
        adapter.join(500 ether);
        assertEq(gold.balanceOf(this),       0 ether);
        assertEq(gold.balanceOf(adapter), 1500 ether);
        adapter.exit(250 ether);
        assertEq(gold.balanceOf(this),     250 ether);
        assertEq(gold.balanceOf(adapter), 1250 ether);
    }
    function test_lock() public {
        assertEq(vat.Ink(gold_ilk, this), 0 ether);
        assertEq(adapter.balanceOf(this), 1000 ether);
        vat.frob(gold_ilk, 6 ether, 0);
        assertEq(vat.Ink(gold_ilk, this), 6 ether);
        assertEq(adapter.balanceOf(this), 994 ether);
        vat.frob(gold_ilk, -6 ether, 0);
        assertEq(vat.Ink(gold_ilk, this), 0 ether);
        assertEq(adapter.balanceOf(this), 1000 ether);
    }
    function test_calm() public {
        // calm means that the debt ceiling is not exceeded
        // it's ok to increase debt as long as you remain calm
        vat.file(gold_ilk, 'line', 10 ether);
        assertTrue( try_frob(gold_ilk, 10 ether, 9 ether));
        // only if under debt ceiling
        assertTrue(!try_frob(gold_ilk,  0 ether, 2 ether));
    }
    function test_cool() public {
        // cool means that the debt has decreased
        // it's ok to be over the debt ceiling as long as you're cool
        vat.file(gold_ilk, 'line', 10 ether);
        assertTrue(try_frob(gold_ilk, 10 ether,  8 ether));
        vat.file(gold_ilk, 'line', 5 ether);
        // can decrease debt when over ceiling
        assertTrue(try_frob(gold_ilk,  0 ether, -1 ether));
    }
    function test_safe() public {
        // safe means that the cdp is not risky
        // you can't frob a cdp into unsafe
        vat.frob(gold_ilk, 10 ether, 5 ether);                // safe draw
        assertTrue(!try_frob(gold_ilk, 0 ether, 6 ether));  // unsafe draw
    }
    function test_nice() public {
        // nice means that the collateral has increased or the debt has
        // decreased. remaining unsafe is ok as long as you're nice

        vat.frob(gold_ilk, 10 ether, 10 ether);
        vat.file(gold_ilk, 'spot', ray(0.5 ether));  // now unsafe

        // debt can't increase if unsafe
        assertTrue(!try_frob(gold_ilk,  0 ether,  1 ether));
        // debt can decrease
        assertTrue( try_frob(gold_ilk,  0 ether, -1 ether));
        // ink can't decrease
        assertTrue(!try_frob(gold_ilk, -1 ether,  0 ether));
        // ink can increase
        assertTrue( try_frob(gold_ilk,  1 ether,  0 ether));

        // cdp is still unsafe
        // ink can't decrease, even if debt decreases more
        assertTrue(!this.try_frob(gold_ilk, -2 ether, -4 ether));
        // debt can't increase, even if ink increases more
        assertTrue(!this.try_frob(gold_ilk,  5 ether,  1 ether));

        // ink can decrease if end state is safe
        assertTrue( this.try_frob(gold_ilk, -1 ether, -4 ether));
        vat.file(gold_ilk, 'spot', ray(0.4 ether));  // now unsafe
        // debt can increase if end state is safe
        assertTrue( this.try_frob(gold_ilk,  5 ether, 1 ether));
    }

    function test_happy_bite() public {
        // spot = tag / (par . mat)
        // tag=5, mat=2
        vat.file(gold_ilk, 'spot', ray(2.5 ether));
        vat.frob(gold_ilk,  40 ether, 100 ether);

        // tag=4, mat=2
        vat.file(gold_ilk, 'spot', ray(2 ether));  // now unsafe

        assertEq(vat.Ink(gold_ilk, this),  40 ether);
        assertEq(vat.Art(gold_ilk, this), 100 ether);
        assertEq(vat.woe(), 0 ether);
        assertEq(adapter.balanceOf(this), 960 ether);
        uint id = vat.bite(gold_ilk, this);
        assertEq(vat.Ink(gold_ilk, this), 0);
        assertEq(vat.Art(gold_ilk, this), 0);
        assertEq(vat.sin(vat.era()), 100 ether);
        assertEq(adapter.balanceOf(this), 960 ether);

        vat.file("lump", 100 ether);
        uint auction = vat.flip(id, 100 ether);  // flip all the tab

        assertEq(pie.balanceOf(vat),   0 ether);
        flip.tend(auction, 40 ether,   1 ether);
        assertEq(pie.balanceOf(vat),   1 ether);
        flip.tend(auction, 40 ether, 100 ether);
        assertEq(pie.balanceOf(vat), 100 ether);

        assertEq(pie.balanceOf(this),       0 ether);
        assertEq(adapter.balanceOf(this), 960 ether);
        vat.suck(this, 100 ether);  // magic up some pie for bidding
        flip.dent(auction, 38 ether,  100 ether);
        assertEq(pie.balanceOf(this), 100 ether);
        assertEq(pie.balanceOf(vat),  100 ether);
        assertEq(adapter.balanceOf(this), 962 ether);
        assertEq(vat.Gem(gold_ilk, this), 962 ether);

        assertEq(vat.sin(vat.era()), 100 ether);
        assertEq(pie.balanceOf(vat), 100 ether);
        vat.flog(vat.era());
        assertEq(vat.sin(vat.era()),   0 ether);
        assertEq(pie.balanceOf(vat),   0 ether);
    }

    function test_floppy_bite() public {
        vat.file(gold_ilk, 'spot', ray(2.5 ether));
        vat.frob(gold_ilk,  40 ether, 100 ether);
        vat.file(gold_ilk, 'spot', ray(2 ether));  // now unsafe
        vat.bite(gold_ilk, this);

        assertEq(vat.sin(vat.era()), 100 ether);
        vat.flog(vat.era());
        assertEq(vat.woe(), 100 ether);

        vat.file("lump", 10 ether);
        uint f1 = vat.flop();
        assertEq(vat.woe(), 100 ether);
        flop.dent(f1, 1000 ether, 10 ether);
        assertEq(vat.woe(),  90 ether);

        assertEq(gov.balanceOf(this),  100 ether);
        flop.warp(4 hours);
        flop.deal(f1);
        assertEq(gov.balanceOf(this), 1100 ether);
    }

    function test_flappy_bite() public {
        // get some surplus
        vat.suck(vat, 100 ether);
        assertEq(pie.balanceOf(vat),  100 ether);
        assertEq(gov.balanceOf(this), 100 ether);

        vat.file("lump", 100 ether);
        uint id = vat.flap();

        assertEq(pie.balanceOf(this),   0 ether);
        assertEq(gov.balanceOf(this), 100 ether);
        flap.tend(id, 100 ether, 10 ether);
        flap.warp(4 hours);
        flap.deal(id);
        assertEq(pie.balanceOf(this),   100 ether);
        assertEq(gov.balanceOf(this),    90 ether);
    }
}