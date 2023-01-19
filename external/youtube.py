import sys
import argparse

import pytube


def fetch_stream_url(y: pytube.YouTube):
    # Trying to get audio only url
    stream = y.streams.filter(only_audio=True).order_by("abr").desc().first()
    if stream is not None:
        return stream.url
    stream = y.streams.order_by("abr").desc().first()
    if stream is not None:
        return stream.url
    return None


def fetch_author(y: pytube.YouTube):
    return y.author


def fetch_title(y: pytube.YouTube):
    return y.title


def fetch_description(y: pytube.YouTube):
    return y.description


def fetch_duration(y: pytube.YouTube):
    return y.length


def parse_args():
    args = argparse.ArgumentParser()

    args.add_argument("url")

    return args.parse_args()


def print_video(y: pytube.YouTube, url: str = None):
    if url is None:
        print(f"url: {fetch_stream_url(y)}")
    else:
        print(f"url: {url}")

    print(f"author: {fetch_author(y)}")
    print(f"title: {fetch_title(y)}")
    print(f"duration: {fetch_duration(y)}")
    print("eof: ")


def print_video_link(url: str):
    print_video(pytube.YouTube(url))


def print_playlist(url: str):
    playlist = pytube.Playlist(url)
    for video in playlist.videos:
        print_video(
            y=video,
            url=video.watch_url,
        )


def main(args):
    if "/playlist?list=" in args.url:
        print_playlist(args.url)
    else:
        print_video_link(args.url)


if __name__ == "__main__":
    sys.exit(main(parse_args()))
