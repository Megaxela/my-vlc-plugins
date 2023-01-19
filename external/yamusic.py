import sys
import argparse
import re
import os

import yandex_music

TOKEN_PARSE_RE = re.compile("\\?access_token=(.+)&?")
PLAYLIST_PARSE_RE = re.compile("/users/(.*)/playlists/([0-9]+)")
TRACK_PARSE_RE = re.compile("/album/([0-9]+)/track/([0-9]+)")
ALBUM_PARSE_RE = re.compile("/album/([0-9]+)")
ARTIST_PARSE_RE = re.compile("/artist/([0-9]+)(/tracks)?")


def fetch_stream_url(track: yandex_music.track.track.Track):
    info = sorted(
        filter(lambda x: x.codec == "mp3", track.get_download_info()),
        key=lambda x: x.bitrate_in_kbps,
        reverse=True,
    )

    if not info:
        return None

    return info[0].get_direct_link()


def fetch_author(track: yandex_music.track.track.Track):
    return ", ".join((artist.name for artist in track.artists))


def fetch_title(track: yandex_music.track.track.Track):
    return track.title


def fetch_duration(track: yandex_music.track.track.Track):
    if not track.duration_ms:
        return 0
    return track.duration_ms // 1000


def parse_args():
    args = argparse.ArgumentParser()

    args.add_argument("url")

    return args.parse_args()


def print_track(track: yandex_music.track.track.Track, url=None):
    if url is None:
        print(f"url: {fetch_stream_url(track)}")
    else:
        print(f"url: {url}")

    print(f"author: {fetch_author(track)}")
    print(f"title: {fetch_title(track)}")
    print(f"duration: {fetch_duration(track)}")
    print("eof: ")


def print_yamusic_track(track_id: str, client: yandex_music.Client):
    track = client.tracks([track_id])[0]
    print_track(track)


def print_yamusic_playlist(
    user_name: str, playlist_id: str, client: yandex_music.Client
):
    # This should be fixed here: https://github.com/MarshalX/yandex-music-api/issues/413
    user_resp = client._request.get(f"{client.base_url}/users/{user_name}")

    playlist = client.playlists_list([f'{user_resp["uid"]}:{playlist_id}'])[0]

    playlist_tracks = playlist.fetch_tracks()
    for track in playlist_tracks:
        fetched_track = track.fetch_track()
        print_track(
            track=fetched_track,
            url=f"https://music.yandex.ru/album/{fetched_track.albums[0].id}/track/{track.id}?access_token={client.token}",
        )


def print_yamusic_album(album_id: str, client: yandex_music.Client):
    album = client.albums_with_tracks(album_id)
    if album is None:
        return None

    for volume in album.volumes:
        for track in volume:
            print_track(
                track=track,
                url=f"https://music.yandex.ru/album/{album_id}/track/{track.id}?access_token={client.token}",
            )


def print_yamusic_artist(artist_id: str, client: yandex_music.Client):
    artist = client.artists([artist_id])[0]
    if artist is None:
        return

    per_page = 20
    tracks_page = artist.get_tracks(
        page=0,
        page_size=per_page,
    )

    fetched = 0

    while True:
        for track in tracks_page.tracks:
            print_track(
                track=track,
                url=f"https://music.yandex.ru/album/{track.albums[0].id}/track/{track.id}?access_token={client.token}",
            )

        fetched += len(tracks_page)

        if fetched >= tracks_page.pager.total:
            break

        tracks_page = artist.get_tracks(
            page=tracks_page.pager.page + 1,
            page_size=per_page,
        )


def main(args):
    token_match = TOKEN_PARSE_RE.search(args.url)
    if not token_match:
        print("No token provided")
        sys.exit(1)

    playlist_match = PLAYLIST_PARSE_RE.search(args.url)
    track_match = TRACK_PARSE_RE.search(args.url)
    album_match = ALBUM_PARSE_RE.search(args.url)
    artist_match = ARTIST_PARSE_RE.search(args.url)

    yandex_music.Client.notice_displayed = True
    client = yandex_music.Client(token_match[1]).init()

    if playlist_match:
        print_yamusic_playlist(playlist_match[1], playlist_match[2], client)
    elif track_match:
        print_yamusic_track(f"{track_match[2]}:{track_match[1]}", client)
    elif album_match:
        print_yamusic_album(album_match[1], client)
    elif artist_match:
        print_yamusic_artist(artist_match[1], client)


if __name__ == "__main__":
    sys.exit(main(parse_args()))
