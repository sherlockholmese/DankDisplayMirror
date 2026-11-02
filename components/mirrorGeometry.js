.pragma library

// Size of the source picture on the destination, matching wl-mirror's --scaling modes.
function pictureSize(sourceWidth, sourceHeight, destinationWidth, destinationHeight, scaling) {
    if (!(sourceWidth > 0 && sourceHeight > 0 && destinationWidth > 0 && destinationHeight > 0))
        return { "width": destinationWidth, "height": destinationHeight };

    const widthRatio = destinationWidth / sourceWidth;
    const heightRatio = destinationHeight / sourceHeight;
    const fit = Math.min(widthRatio, heightRatio);
    let factor = fit;
    if (scaling === "cover")
        factor = Math.max(widthRatio, heightRatio);
    else if (scaling === "exact")
        factor = fit >= 1 ? Math.floor(fit) : 1 / Math.ceil(1 / fit);

    return { "width": sourceWidth * factor, "height": sourceHeight * factor };
}

// How the picture meets the destination edges: "fills", "barsSides", "barsEnds", "barsAll", "cropSides" or "cropEnds".
function edgeFit(sourceWidth, sourceHeight, destinationWidth, destinationHeight, scaling) {
    const picture = pictureSize(sourceWidth, sourceHeight, destinationWidth, destinationHeight, scaling);
    const tolerance = 1;
    const narrower = picture.width < destinationWidth - tolerance;
    const shorter = picture.height < destinationHeight - tolerance;

    if (narrower && shorter)
        return "barsAll";
    if (narrower)
        return picture.height > destinationHeight + tolerance ? "cropEnds" : "barsSides";
    if (shorter)
        return picture.width > destinationWidth + tolerance ? "cropSides" : "barsEnds";
    if (picture.width > destinationWidth + tolerance)
        return "cropSides";
    if (picture.height > destinationHeight + tolerance)
        return "cropEnds";
    return "fills";
}
