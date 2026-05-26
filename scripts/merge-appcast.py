#!/usr/bin/env python3
"""Merge newly generated Sparkle items into an existing appcast feed."""

from __future__ import annotations

import argparse
import copy
import xml.etree.ElementTree as ET
from pathlib import Path

SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
DC_NS = "http://purl.org/dc/elements/1.1/"

ET.register_namespace("sparkle", SPARKLE_NS)
ET.register_namespace("dc", DC_NS)


def local_name(tag: str) -> str:
    if "}" in tag:
        return tag.rsplit("}", 1)[1]
    return tag


def child_text(item: ET.Element, name: str) -> str:
    for child in item:
        if local_name(child.tag) == name:
            return (child.text or "").strip()
    return ""


def enclosure(item: ET.Element) -> ET.Element | None:
    for child in item:
        if local_name(child.tag) == "enclosure":
            return child
    return None


def enclosure_attr(node: ET.Element | None, name: str) -> str:
    if node is None:
        return ""
    for key, value in node.attrib.items():
        if local_name(key) == name:
            return value.strip()
    return ""


def item_key(item: ET.Element) -> tuple[str, str, str, str]:
    enclosure_node = enclosure(item)
    return (
        enclosure_attr(enclosure_node, "url"),
        enclosure_attr(enclosure_node, "shortVersionString") or child_text(item, "shortVersionString"),
        enclosure_attr(enclosure_node, "version") or child_text(item, "version"),
        child_text(item, "title"),
    )


def load_channel(path: Path) -> tuple[ET.ElementTree, ET.Element]:
    tree = ET.parse(path)
    channel = tree.getroot().find("channel")
    if channel is None:
        raise ValueError(f"Missing <channel> in {path}")
    return tree, channel


def merge_appcasts(new_path: Path, existing_path: Path, output_path: Path) -> None:
    existing_tree, existing_channel = load_channel(existing_path)
    _, new_channel = load_channel(new_path)

    merged_items: list[ET.Element] = []
    seen: set[tuple[str, str, str, str]] = set()

    for source_channel in (new_channel, existing_channel):
        for item in source_channel.findall("item"):
            key = item_key(item)
            if key in seen:
                continue
            seen.add(key)
            merged_items.append(copy.deepcopy(item))

    for item in list(existing_channel.findall("item")):
        existing_channel.remove(item)

    for item in merged_items:
        existing_channel.append(item)

    ET.indent(existing_tree, space="  ")
    existing_tree.write(output_path, encoding="utf-8", xml_declaration=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--new", required=True, dest="new_path", type=Path)
    parser.add_argument("--existing", required=True, dest="existing_path", type=Path)
    parser.add_argument("--output", required=True, dest="output_path", type=Path)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    merge_appcasts(args.new_path, args.existing_path, args.output_path)


if __name__ == "__main__":
    main()
