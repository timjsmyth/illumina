#!/usr/bin/env python2

from glob import glob
import ogr, osr, gdal
import yaml, h5py
import hdftools
from subprocess import call
import os

def warp(srcfiles, projection, extent):
    bounding_box = [
        extent["xmin"],
        extent["ymin"],
        extent["xmax"],
        extent["ymax"] ]

    vrt = gdal.BuildVRT('',srcfiles)
    ds = gdal.Warp( '', vrt,
        format="VRT",
        dstSRS=projection,
        dstNodata=0.,
        outputBounds=bounding_box,
        xRes=extent["pixel_size"],
        yRes=extent["pixel_size"],
        resampleAlg="cubicspline" )

    return ds.GetRasterBand(1).ReadAsArray()

def prep_shp(infile, projection, extent):
        cmd  = ['ogr2ogr']
        cmd += ['-spat',
            extent['xmin'],
            extent['ymin'],
            extent['xmax'],
            extent['ymax']
        ]
        cmd += ['-spat_srs','+init='+projection]
        cmd += ['-t_srs','+init='+projection]
        cmd += ['tmp_select.shp']
        cmd += ['/vsizip/'+os.path.abspath(infile)]
        cmd = map(str,cmd)
        print "EXECUTING :", ' '.join(cmd)
        call(cmd)

        cmd  = ['ogr2ogr']
        cmd += ['tmp_merge.shp']
        cmd += ['tmp_select.shp']
        cmd += ['-dialect','sqlite']
        cmd += ['-sql','SELECT ST_Union(geometry) AS geometry FROM tmp_select']
        print "EXECUTING :", ' '.join(cmd)
        call(cmd)

def rasterize(shpfile, projection, extent):
    width = int(round((extent['xmax'] - extent['xmin']) / extent['pixel_size']))
    height = int(round((extent['ymax'] - extent['ymin']) / extent['pixel_size']))

    geo_transform = (
        extent['xmin'],extent['pixel_size'],0,
        extent['ymax'],0,-extent['pixel_size']
    )
    srs = osr.SpatialReference()
    srs.ImportFromEPSG(int(projection.split(':')[1]))
    proj = srs.ExportToWkt()

    data_source = gdal.OpenEx(shpfile, gdal.OF_VECTOR)
    driver = gdal.GetDriverByName('MEM')  # In memory dataset
    target_ds = driver.Create('', width, height, 1, gdal.GDT_Byte)
    target_ds.SetGeoTransform(geo_transform)
    target_ds.SetProjection(proj)
    gdal.Rasterize(target_ds, data_source,
        bands=[1],
        burnValues=[1],
        inverse=True,
        allTouched=True)
    return target_ds.GetRasterBand(1).ReadAsArray()

def save(params, data, dstname, scale_factor=1.):
    scaled_data = [ d*scale_factor for d in data ]
    ds = hdftools.from_domain(params,scaled_data)
    ds.save(dstname)

with open(glob("*.ini")[0]) as f:
    params = yaml.safe_load(f)

if os.path.isfile("GHSL.zip"):
    print "Found GHSL.zip file, processing."
    data = [ warp(["/vsizip/GHSL.zip/GHSL.tif"], params['srs'], extent) \
        for extent in params['extents'] ]
    save(params, data, "obstf")
else:
    print "WARNING: Could not find GHSL.zip file."
    print "If you don't indent to use it, you can safely ignore this."

files = sorted(glob("SRTM/*.hgt"))
if not len(files):
    print "ERROR: Could not find SRTM file(s), aborting."
    raise SystemExit
print "    ".join(map(str,files))
data = [ warp(files, params['srs'], extent) \
    for extent in params['extents'] ]
save(params, data, "srtm")

files = sorted(glob("VIIRS-DNB/*.tif"))
if not len(files):
    print "WARNING: Did not find VIIRS file(s)."
    print "If you don't intend to use zones inventory, you can safely ignore this."
else:
    if not os.path.isfile("hydropolys.zip"):
        print "ERROR: Could not find hydropolys.zip file, aborting."
        raise SystemExit

    print "    ".join(map(str,files))
    data = [ warp(files, params['srs'], extent) \
        for extent in params['extents'] ]
    save(params, data, "stable_lights")

    prep_shp(
        "hydropolys.zip/hydropolys.shp",
        params['srs'],
        params['extents'][-1]
    )
    data = [ rasterize("tmp_merge.shp", params['srs'], extent) \
        for extent in params['extents'] ]
    save(params, data, "water_mask")

    for fname in glob("tmp*"):
        os.remove(fname)

    print "Done."
